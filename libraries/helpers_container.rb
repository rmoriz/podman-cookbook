# frozen_string_literal: true

module PodmanCookbook
  module Helpers
    module Container
      def cgroupv2?
        node.dig('filesystem', 'by_device').nil? ? false : node.dig('filesystem', 'by_device').key?('cgroup2')
      end

      def coerce_labels(value)
        case value
        when Hash, nil
          value
        else
          Array(value).each_with_object({}) do |label, memo|
            key, _, rest = label.partition('=')
            memo[key] = rest
          end
        end
      end

      def coerce_annotation(value)
        return [] if value.nil? || value == ''
        entries = Array(value).map(&:to_s)
        entries.each do |entry|
          unless entry.match?(/\A\S+=\S*\z/)
            raise Chef::Exceptions::ValidationFailed, "annotation #{entry} is not KEY=VALUE"
          end
        end
        entries.sort
      end

      def coerce_links(value)
        return value if value.nil?
        ::UnorderedArray.new(
          Array(value).map do |link|
            if link =~ %r{^/(?<source>.+):/#{name}/(?<dest>.+)}
              "#{Regexp.last_match[:source]}:#{Regexp.last_match[:dest]}"
            else
              link
            end
          end
        )
      end

      def to_bytes(value)
        number = value.to_i
        unit = value.to_s.gsub(/\d/, '').upcase
        multiplier = case unit
                     when 'B' then 1
                     when 'K' then 1024
                     when 'M' then 1024**2
                     when 'G' then 1024**3
                     when 'T' then 1024**4
                     else 1
                     end
        number * multiplier
      end

      def coerce_to_bytes(value)
        value.is_a?(Integer) || value.nil? ? value : to_bytes(value)
      end

      def coerce_cpus(value)
        value.nil? ? 0 : (value.to_f * (10**9)).to_i
      end

      def coerce_ulimits(value)
        return value if value.nil?
        Array(value).map do |ulimit|
          ulimit.is_a?(Hash) ? "#{ulimit['Name']}=#{ulimit['Soft']}:#{ulimit['Hard']}" : ulimit
        end
      end

      def coerce_volumes(value)
        case value
        when PartialHash, nil
          value
        when Hash
          PartialHash.new.merge(value)
        else
          binds = []
          volumes = Array(value)
          volumes.delete_if do |entry|
            parts = entry.split(':')
            binds << entry if parts.length > 1
          end
          volumes_binds(binds) unless binds.empty?
          volumes.each_with_object(PartialHash.new) { |volume, memo| memo[volume] = {} }
        end
      end

      def coerce_tmpfs(value)
        case value
        when Hash, nil
          value
        when Array
          value.to_h { |path| [path, ''] }
        end
      end

      def parse_port(value)
        _, protocol = value.split('/')
        parts = value.split(':')
        case parts.length
        when 3
          host_ip = parts.first
          host_port = parts[1].split('-')
          container_port = parts[2].split('-')
        when 2
          host_ip = '0.0.0.0'
          host_port = parts.first.split('-')
          container_port = parts[1].split('-')
        else
          host_ip = ''
          host_port = ['']
          container_port = parts.first.split('-')
        end
        host_port.map!(&:to_i) unless host_port == ['']
        container_port.map!(&:to_i)
        host_port = (host_port.first..host_port.last).to_a if host_port.count > 1
        container_port = (container_port.first..container_port.last).to_a if container_port.count > 1
        protocol = 'tcp' if protocol.nil?
        Array(container_port).map.with_index do |_, index|
          {
            'host_ip' => host_ip,
            'host_port' => host_port[index].to_s,
            'container_port' => "#{container_port[index]}/#{protocol}",
          }
        end
      end

      def coerce_exposed_ports(value)
        return value if value.is_a?(Hash) || value.nil?
        Array(value).flat_map { |port| parse_port(port) }.to_h { |entry| [entry['container_port'], {}] }
      end

      # Convenience setter mirroring docker_container: `port '8080:80'` fills
      # exposed_ports and port_bindings.
      def port(value = nil)
        return @port if value.nil?
        exposed_ports coerce_exposed_ports(value)
        port_bindings coerce_port_bindings(value)
        @port = value
      end

      def coerce_port_bindings(value)
        return value if value.nil?
        return normalize_port_bindings(value) if value.is_a?(Hash)

        Array(value).flat_map { |port| parse_port(port) }.each_with_object({}) do |entry, memo|
          memo[entry['container_port']] ||= []
          memo[entry['container_port']] << { 'HostIp' => entry['host_ip'], 'HostPort' => entry['host_port'] }
        end
      end

      # Podman 4 reports `0.0.0.0` for a wildcard bind address and Podman 5
      # reports the same thing as an empty string. Both mean "every address",
      # so they are canonicalised: otherwise a converged container drifts
      # against its own inspect output on one of the versions.
      def normalize_port_bindings(bindings)
        (bindings || {}).each_with_object({}) do |(port, list), memo|
          memo[port] = Array(list).map do |binding|
            ip = binding['HostIp'].to_s
            binding.merge('HostIp' => ip.empty? ? '0.0.0.0' : ip)
          end
        end
      end

      def coerce_buildargs(value)
        return value if value.is_a?(String)
        value.map { |key, val| "#{key}=#{val}" }
      end

      # Parses repo/tag out of an image reference, mirroring docker_container.
      def image(value = nil)
        if value
          if value.include?('@')
            repo_part, tag_part = value.split('@', 2)
          else
            dirname, _, basename = value.rpartition('/')
            repo_part, _, tag_part = basename.rpartition(':')
            repo_part = [dirname, repo_part].join('/') unless dirname.empty?
            tag_part = nil if tag_part.empty?
          end
          repo repo_part
          tag tag_part if tag_part
        end
        "#{repo}:#{tag}"
      end

      def container_network_mode(value)
        # The Docker cookbook accepts `default` as an alias for the bridge.
        return 'bridge' if value == 'default'
        return value unless value.is_a?(String) && value.start_with?('container:')
        reference = value.split(':', 2)[1]
        info = podman_inspect('container', reference)
        info && info['Id'] ? "container:#{info['Id']}" : value
      rescue StandardError
        value
      end

      # Image labels are inherited by the container. Drop them so they do not
      # show up as a drift the container never asked for.
      def load_container_labels(container_info)
        image = container_info.dig('Config', 'Image')
        image_labels = image ? podman_inspect('image', image)&.fetch('Labels', nil) || {} : {}
        (container_info.dig('Config', 'Labels') || {}).reject do |key, value|
          key == 'io.buildah.version' || image_labels[key] == value
        end
      end

      # Podman writes annotations of its own: `io.podman.annotations.*` for flags
      # like `--rm`, plus `io.container.manager` and the effective stop signal
      # once a container is started. None of them is a property here, so they
      # would drift on every run.
      PODMAN_ANNOTATION_PREFIX = 'io.podman.annotations.'
      PODMAN_ANNOTATIONS = %w(io.container.manager org.opencontainers.image.stopSignal).freeze

      def load_container_annotations(config)
        own = (config['Annotations'] || {}).reject do |key, _|
          key.start_with?(PODMAN_ANNOTATION_PREFIX) || PODMAN_ANNOTATIONS.include?(key)
        end
        own.map { |key, value| "#{key}=#{value}" }.sort
      end

      def ip_address_from_container(container_info)
        networks = container_info.dig('NetworkSettings', 'Networks') || {}
        first = networks.values.first || {}
        first.dig('IPAMConfig', 'IPv4Address')
      end

      # Builds the argument list for podman create/run from resource properties.
      # `env_file` is not a Podman flag. Docker folds the file contents into the
      # container env, and so does Podman's inspect, so read the files and pass
      # their entries as --env. That keeps an unchanged env file from looking
      # like drift on every run.
      def env_file_entries(resource)
        entries = Array(resource.env_file).flat_map do |path|
          ::File.readlines(path, chomp: true)
        rescue Errno::ENOENT
          Chef::Log.warn("podman_container: env_file #{path} does not exist")
          []
        end
        entries.reject { |line| line.empty? || line.start_with?('#') }
      end

      # Podman has no `--link` flag and the inspect output does not report
      # links. Record them under numbered labels so an unchanged set is still
      # comparable.
      LINK_LABEL_PREFIX = 'podman_link_'

      def load_container_links(labels)
        links = labels.select { |key, _| key.start_with?(LINK_LABEL_PREFIX) }
                      .sort_by { |key, _| key.delete_prefix(LINK_LABEL_PREFIX).to_i }
                      .map { |_, value| value }
        links.empty? ? nil : ::UnorderedArray.new(links)
      end

      # The configured domain is folded into `--hostname`, so strip it again to
      # compare the hostname the recipe asked for.
      def load_hostname(config, new_resource)
        hostname = config['Hostname'].to_s
        domain = new_resource.domain_name.to_s
        return if hostname.empty?
        return hostname if domain.empty?

        hostname.delete_suffix(".#{domain}")
      end

      # Podman has no `--volume-driver` flag. A driver is only accepted as an
      # option of the `--mount` syntax, so a volume that names a real volume is
      # rendered that way when a driver is configured. Bind mounts and
      # anonymous volumes keep the short `--volume` form.
      def volume_flags(resource)
        (Array(resource.volumes_binds) + resource.volumes.keys).flat_map do |spec|
          source, destination, opts = spec.split(':', 3)
          next ['--volume', spec] unless resource.volume_driver && destination && !volume_source_path?(source)

          mount = "type=volume,source=#{source},destination=#{destination},volume-driver=#{resource.volume_driver}"
          mount += ',readonly' if opts.to_s.split(',').include?('ro')
          ['--mount', mount]
        end
      end

      def volume_source_path?(source)
        source.start_with?('/', '.', '~')
      end

      def container_flags(resource)
        flags = ['--name', resource.container_name]
        (resource.labels || {}).each { |key, value| flags.push('--label', "#{key}=#{value}") }
        Array(resource.annotation).each { |entry| flags.push('--annotation', entry) }
        Array(resource.env).each { |entry| flags.push('--env', entry) }
        env_file_entries(resource).each { |entry| flags.push('--env', entry) }
        resource.exposed_ports.each_key { |port| flags.push('--expose', port) }
        resource.port_bindings.each do |container_port, bindings|
          bindings.each do |binding|
            host = binding['HostIp'].to_s.empty? ? '' : "#{binding['HostIp']}:"
            flags.push('--publish', "#{host}#{binding['HostPort']}:#{container_port}")
          end
        end
        flags << '--publish-all' if resource.publish_all_ports
        flags.concat(volume_flags(resource))
        Array(resource.volumes_from).each { |from| flags.push('--volumes-from', from) }
        (resource.tmpfs || {}).each { |path, opts| flags.push('--tmpfs', opts.to_s.empty? ? path : "#{path}:#{opts}") }
        Array(resource.extra_hosts).each { |host| flags.push('--add-host', host) }
        # Podman resolves containers by name through its network DNS, so an
        # explicit `--link` is not needed; the labels only keep the configured
        # set comparable.
        Array(resource.links).each_with_index { |link, index| flags.push('--label', "#{LINK_LABEL_PREFIX}#{index}=#{link}") }
        resource.dns.each { |server| flags.push('--dns', server) }
        resource.dns_search.each { |domain| flags.push('--dns-search', domain) }
        hostname = [resource.hostname.to_s, resource.domain_name.to_s].reject(&:empty?).join('.')
        flags.push('--hostname', hostname) unless hostname.empty?
        flags.push('--mac-address', resource.mac_address) if resource.mac_address
        flags.push('--ip', resource.ip_address) if resource.ip_address
        resource.network_aliases.each { |network_alias| flags.push('--network-alias', network_alias) }
        flags.push('--network', resource.network_disabled ? 'none' : container_network_mode(resource.network_mode)) if resource.network_mode || resource.network_disabled
        Array(resource.cap_add).each { |cap| flags.push('--cap-add', cap) }
        Array(resource.cap_drop).each { |cap| flags.push('--cap-drop', cap) }
        Array(resource.security_opt).each { |opt| flags.push('--security-opt', opt) }
        resource.devices.each { |device| flags.push('--device', device) }
        Array(resource.ulimits).each { |ulimit| flags.push('--ulimit', ulimit) }
        (resource.sysctls || {}).each { |key, value| flags.push('--sysctl', "#{key}=#{value}") }
        flags << '--privileged' if resource.privileged
        flags << '--init' if resource.init
        flags << '--read-only' if resource.ro_rootfs
        flags << '--tty' if resource.tty
        flags << '--interactive' if resource.open_stdin
        flags.push('--attach', 'stdout') if resource.attach_stdout
        flags.push('--attach', 'stderr') if resource.attach_stderr
        flags.push('--attach', 'stdin') if resource.attach_stdin
        flags << '--rm' if resource.autoremove
        flags.push('--user', resource.user) if resource.user
        flags.push('--workdir', resource.working_dir) if resource.working_dir
        flags.push('--entrypoint', resource.entrypoint.join(' ')) unless resource.entrypoint.nil? || resource.entrypoint.empty?
        flags.push('--cpus', (resource.cpus.to_f / 10**9).to_s) if resource.cpus.positive?
        flags.push('--cpu-shares', resource.cpu_shares.to_s) if resource.cpu_shares.positive?
        flags.push('--cpuset-cpus', resource.cpuset_cpus) unless resource.cpuset_cpus.to_s.empty?
        flags.push('--memory', resource.memory.to_s) if resource.memory.to_i.positive?
        flags.push('--memory-swap', resource.memory_swap.to_s) if resource.memory_swap
        flags.push('--memory-swappiness', resource.memory_swappiness.to_s) if resource.memory_swappiness.positive?
        flags.push('--memory-reservation', resource.memory_reservation.to_s) if resource.memory_reservation.to_i.positive?
        flags.push('--shm-size', resource.shm_size.to_s) if resource.shm_size
        flags.push('--cgroup-parent', resource.cgroup_parent) unless resource.cgroup_parent.to_s.empty?
        flags.push('--pod', resource.pod) if resource.respond_to?(:pod) && resource.pod
        flags.push('--cgroupns', resource.cgroup_ns) if resource.cgroup_ns
        flags.push('--ipc', resource.ipc_mode) unless resource.ipc_mode.to_s.empty?
        flags.push('--pid', resource.pid_mode) unless resource.pid_mode.to_s.empty?
        flags.push('--userns', resource.userns_mode) unless resource.userns_mode.to_s.empty?
        flags.push('--uts', resource.uts_mode) unless resource.uts_mode.to_s.empty?
        flags << '--oom-kill-disable' if resource.oom_kill_disable
        flags.push('--oom-score-adj', resource.oom_score_adj.to_s) if resource.oom_score_adj
        if resource.gpus
          gpus = resource.gpus.to_s
          gpus = "driver=#{resource.gpu_driver},#{gpus}" unless resource.gpu_driver.to_s.empty? || gpus.include?('driver=')
          flags.push('--gpus', gpus)
        end
        # `--runtime` is hidden from `--help` in Podman 6 but still accepted and
        # passed on to the OCI runtime selected per container.
        flags.push('--runtime', resource.runtime) unless resource.runtime.to_s.empty?
        flags.concat(log_flags(resource))
        flags.concat(healthcheck_flags(resource))
        flags.concat(restart_flags(resource))
        flags
      end

      # The driver Podman uses when a container does not name one. It comes from
      # containers.conf and differs per distribution, so it is asked for instead
      # of assuming k8s-file.
      def default_log_driver
        @default_log_driver ||= begin
          podman_shell_out('info', '--format', '{{.Host.LogDriver}}').stdout.to_s.strip
                                rescue StandardError
                                  'k8s-file'
        end
      end

      def log_flags(resource)
        return [] unless resource.property_is_set?(:log_driver) || resource.property_is_set?(:log_opts)
        flags = []
        flags.push('--log-driver', resource.log_driver) if resource.log_driver
        resource.log_opts.each { |key, value| flags.push('--log-opt', "#{key}=#{value}") } if resource.log_opts
        flags
      end

      # Health check durations come back from inspect as nanoseconds. Render
      # them the way users write them so an unchanged check does not look like
      # drift.
      def normalized_duration(value)
        return value unless value.is_a?(Integer) && value.positive?

        seconds, nanos = value.divmod(1_000_000_000)
        return "#{seconds}s" if nanos.zero?

        fraction = format('%09d', nanos).sub(/0+\z/, '')
        "#{seconds}.#{fraction}s"
      end

      def normalize_health_check(check)
        return check if check.nil?
        check.each_with_object({}) do |(key, value), memo|
          memo[key] = if %w(Interval Timeout StartPeriod).include?(key.to_s)
                        normalized_duration(value)
                      elsif key.to_s == 'Test'
                        Array(value).map { |entry| entry.to_s.gsub('\\ ', ' ') }
                      else
                        value
                      end
        end
      end

      def healthcheck_flags(resource)
        return [] unless resource.health_check
        check = resource.health_check
        flags = []
        test = Array(check['Test'] || check[:Test]).map(&:to_s)
        return ['--no-healthcheck'] if test.first == 'NONE'

        test.shift if %w(CMD CMD-SHELL).include?(test.first)
        flags.push('--health-cmd', test.shelljoin) unless test.empty?
        interval = check['Interval'] || check[:Interval]
        timeout = check['Timeout'] || check[:Timeout]
        retries = check['Retries'] || check[:Retries]
        start_period = check['StartPeriod'] || check[:StartPeriod]
        flags.push('--health-interval', interval.to_s) if interval
        flags.push('--health-timeout', timeout.to_s) if timeout
        flags.push('--health-retries', retries.to_s) if retries
        flags.push('--health-start-period', start_period.to_s) if start_period
        flags
      end

      def restart_flags(resource)
        return [] unless resource.restart_policy
        policy = resource.restart_policy
        policy = "on-failure:#{resource.restart_maximum_retry_count}" if policy == 'on-failure' && resource.restart_maximum_retry_count.positive?
        ['--restart', policy]
      end

      def container_state(container_name)
        info = podman_inspect('container', container_name)
        info ? info['State'] || {} : {}
      rescue StandardError
        {}
      end

      def wait_running_state(container_name, running)
        # Reached from the action class, where the timeout lives on the resource.
        tries = podman_resource.running_wait_time
        tries.times do
          current = container_state(container_name)
          return if current['Running'] == running
          return if running && current['Running'] == false && current.key?('ExitCode')
          sleep 1
        end
        desired = running ? 'running' : 'not running'
        raise "Container #{container_name} failed to change to #{desired} state"
      end
    end
  end
end
