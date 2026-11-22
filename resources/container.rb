# frozen_string_literal: true

unified_mode true
use '_partial/_base'
use '_partial/_logging'

resource_name :podman_container
provides :podman_container

include PodmanCookbook::Helpers::Container

property :container_name, String, name_property: true
property :repo, String, default: lazy { container_name }
property :tag, String, default: 'latest'
property :command, [Array, String, nil], coerce: proc { |value| value.is_a?(String) ? ::Shellwords.shellwords(value) : value }
# krun sizes its microVM through annotations, see
# documentation/alternative-runtimes.md.
property :annotation, [String, Array], default: [], coerce: proc { |value| coerce_annotation(value) }
property :attach_stderr, [true, false], default: false, desired_state: false
property :attach_stdin, [true, false], default: false, desired_state: false
property :attach_stdout, [true, false], default: false, desired_state: false
property :autoremove, [true, false], default: false, desired_state: false
property :cap_add, [Array, nil], coerce: proc { |value| Array(value).empty? ? nil : Array(value) }
property :cap_drop, [Array, nil], coerce: proc { |value| Array(value).empty? ? nil : Array(value) }
property :cgroup_ns, [String, nil], default: lazy { cgroupv2? ? 'private' : 'host' }
property :cgroup_parent, String, default: ''
property :cpus, [Integer, Float], coerce: proc { |value| coerce_cpus(value) }, default: 0
property :cpu_shares, Integer, default: 0
property :cpuset_cpus, String, default: ''
property :detach, [true, false], default: true, desired_state: false
property :devices, Array, default: []
property :dns, Array, default: []
property :dns_search, Array, default: []
property :domain_name, String, default: ''
property :entrypoint, [Array, String, nil], coerce: proc { |value| value.is_a?(String) ? ::Shellwords.shellwords(value) : value }
property :env, UnorderedArrayType, default: []
property :env_file, [Array, String], coerce: proc { |value| Array(value) }, default: [], desired_state: false
property :extra_hosts, [Array, nil], coerce: proc { |value| Array(value).empty? ? nil : Array(value) }
property :exposed_ports, PartialHashType, default: lazy { PartialHash.new },
                                          coerce: proc { |value| coerce_exposed_ports(value) }
property :force, [true, false], default: false, desired_state: false
property :health_check, Hash
property :hostname, String
property :ipc_mode, String, default: 'shareable'
property :labels, [String, Array, Hash], default: {}, coerce: proc { |value| coerce_labels(value) }
property :links, UnorderedArrayType, coerce: proc { |value| coerce_links(value) }
property :init, [TrueClass, FalseClass, nil]
property :ip_address, String
property :mac_address, String
property :memory, [String, Integer], coerce: proc { |value| coerce_to_bytes(value) }, default: 0
property :memory_swap, [String, Integer], coerce: proc { |value| coerce_to_bytes(value) }
property :memory_swappiness, Integer, default: 0
property :memory_reservation, [String, Integer], coerce: proc { |value| coerce_to_bytes(value) }, default: 0
property :network_disabled, [true, false], default: false
property :network_mode, String, default: 'bridge'
property :network_aliases, [String, Array], default: [], coerce: proc { |value| Array(value) }
property :oom_kill_disable, [true, false], default: false
property :oom_score_adj, Integer, default: -500
property :open_stdin, [true, false], default: false, desired_state: false
property :outfile, String
property :port_bindings, PartialHashType, default: lazy { PartialHash.new },
                                          coerce: proc { |value| coerce_port_bindings(value) }
property :pid_mode, String, default: ''
# Podman-only: joins the container to a pod. `network_mode container:<pod>`
# alone no longer resolves a pod name since Podman 6.
property :pod, String
property :privileged, [true, false], default: false
property :publish_all_ports, [true, false], default: false
property :reload_signal, String, default: 'SIGHUP'
property :remove_volumes, [true, false], default: false
property :restart_maximum_retry_count, Integer, default: 0
property :restart_policy, String
# gVisor (`runsc`) and WASM (`crun-wasm`) are selected this way. The name has
# to be known to Podman, see documentation/alternative-runtimes.md.
property :runtime, String, desired_state: false
property :ro_rootfs, [true, false], default: false
property :security_opt, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :shm_size, [String, Integer], default: '64m', coerce: proc { |value| coerce_to_bytes(value) }
property :signal, String, default: 'SIGTERM'
property :stdin_once, [true, false], default: false, desired_state: false
property :sysctls, Hash, default: {}
property :timeout, Integer, desired_state: false
property :tmpfs, [Hash, Array], default: {}, coerce: proc { |value| coerce_tmpfs(value) }
property :tty, [true, false], default: false
property :ulimits, [Array, nil], coerce: proc { |value| coerce_ulimits(value) }
property :user, String
property :userns_mode, String, default: ''
property :uts_mode, String, default: ''
property :volumes, PartialHashType, default: lazy { PartialHash.new }, coerce: proc { |value| coerce_volumes(value) }
property :volumes_from, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :volume_driver, String
property :working_dir, String
property :gpus, [String, nil]
property :gpu_driver, String, default: 'nvidia'

property :volumes_binds, Array, coerce: proc(&:sort)
property :container, Hash, desired_state: false
property :create_options, Hash, default: {}, desired_state: false
property :kill_after, [Integer, NilClass], default: nil, desired_state: false

alias_method :cmd, :command
alias_method :additional_host, :extra_hosts
alias_method :rm, :autoremove
alias_method :remove_automatically, :autoremove
alias_method :host_name, :hostname
alias_method :domainname, :domain_name
alias_method :dnssearch, :dns_search
alias_method :restart_maximum_retries, :restart_maximum_retry_count
alias_method :volume, :volumes
alias_method :binds, :volumes
alias_method :volume_from, :volumes_from
alias_method :destination, :outfile
alias_method :workdir, :working_dir

load_current_value do |new_resource|
  info = podman_inspect('container', container_name)
  current_value_does_not_exist! unless info && info['Id']

  container info
  reload_signal new_resource.reload_signal

  config = info['Config'] || {}
  host_config = info['HostConfig'] || {}

  # Most properties do not accept nil, and partial inspect output (or a Podman
  # version that omits a key) would otherwise raise during the load.
  set = ->(property, value) { send(property, value) unless value.nil? }

  set.call(:image, config['Image'])
  # Podman stores fully-qualified references and its default pid and uts mode,
  # while the resource defaults are short names and empty strings. Without the
  # mapping an unchanged container looks changed on every run.
  reported_image = config['Image'].to_s.sub(%r{\Adocker\.io/library/}, '').sub(%r{\Adocker\.io/}, '')
  configured_image = podman_image_identifier(new_resource.repo, new_resource.tag)
  if reported_image == configured_image
    set.call(:repo, reported_image.sub(/:#{Regexp.escape(new_resource.tag.to_s)}\z/, ''))
  end
  command config['Cmd']
  entrypoint config['Entrypoint']
  env config['Env'] || []
  current_labels = load_container_labels(info)
  links(load_container_links(current_labels))
  labels(current_labels.reject { |key, _| key.start_with?(LINK_LABEL_PREFIX) })
  annotation load_container_annotations(config)
  set.call(:hostname, load_hostname(config, new_resource))
  # Podman has no `--domainname`; the domain is folded into `--hostname`, so
  # `Config.Domainname` stays empty and the configured value is the only
  # comparable state.
  set.call(:domain_name, new_resource.domain_name)
  set.call(:user, config['User'])
  set.call(:working_dir, config['WorkingDir'])
  set.call(:tty, config['Tty'])
  set.call(:open_stdin, config['OpenStdin'])
  set.call(:attach_stdout, config['AttachStdout'])
  set.call(:attach_stderr, config['AttachStderr'])
  set.call(:attach_stdin, config['AttachStdin'])
  set.call(:stdin_once, config['StdinOnce'])
  exposed_ports config['ExposedPorts'] || {}
  health_check normalize_health_check(config['Healthcheck'])

  set.call(:volumes_binds, Array(host_config['Binds']).empty? ? nil : host_config['Binds'])
  volume_driver Array(host_config['Mounts']).find { |mount| mount['Type'] == 'volume' }&.fetch('Driver', nil)
  set.call(:cap_add, host_config['CapAdd'])
  set.call(:cap_drop, host_config['CapDrop'])
  set.call(:cgroup_parent, host_config['CgroupParent'])
  set.call(:cgroup_ns, host_config['CgroupnsMode'])
  devices host_config['Devices'] || []
  dns host_config['Dns'] || []
  dns_search host_config['DnsSearch'] || []
  set.call(:extra_hosts, host_config['ExtraHosts'])
  set.call(:ipc_mode, host_config['IpcMode'])
  set.call(:init, host_config['Init'])
  set.call(:memory, host_config['Memory'])
  set.call(:memory_swap, host_config['MemorySwap'])
  set.call(:memory_swappiness, host_config['MemorySwappiness'])
  set.call(:memory_reservation, host_config['MemoryReservation'])
  set.call(:cpus, host_config['NanoCpus'])
  # Podman reports `none` for a disabled network and the target id for
  # `container:<name>`. Rewrite those spellings back to the configured form so
  # an unchanged container is not recreated on every run.
  mode = host_config['NetworkMode']
  network_disabled(mode == 'none')
  mode = 'bridge' if mode.to_s.empty? || mode == 'none'
  if mode.to_s.start_with?('container:') && new_resource.network_mode.to_s.start_with?('container:') &&
     container_network_mode(new_resource.network_mode) == mode
    mode = new_resource.network_mode
  end
  mode = 'default' if mode == 'bridge' && new_resource.network_mode == 'default'
  set.call(:network_mode, mode)
  set.call(:oom_kill_disable, host_config['OomKillDisable'])
  set.call(:oom_score_adj, host_config['OomScoreAdj'])
  pid_mode = host_config['PidMode']
  set.call(:pid_mode, pid_mode == 'private' ? '' : pid_mode)
  # Inspect reports the pod's infra container id, not the pod name.
  if new_resource.property_is_set?(:pod)
    # A pod that does not exist yet inspects to nil.
    infra = podman_object_exists?('pod', new_resource.pod) && podman_inspect('pod', new_resource.pod)&.fetch('InfraContainerID', nil)
    set.call(:pod, infra && info['Pod'] == infra ? new_resource.pod : nil)
  end
  port_bindings normalize_port_bindings(host_config['PortBindings'])
  set.call(:privileged, host_config['Privileged'])
  set.call(:publish_all_ports, host_config['PublishAllPorts'])
  set.call(:ro_rootfs, host_config['ReadonlyRootfs'])
  set.call(:restart_policy, host_config.dig('RestartPolicy', 'Name'))
  set.call(:restart_maximum_retry_count, host_config.dig('RestartPolicy', 'MaximumRetryCount'))
  set.call(:security_opt, host_config['SecurityOpt'])
  set.call(:shm_size, host_config['ShmSize'])
  sysctls host_config['Sysctls'] || {}
  tmpfs host_config['Tmpfs'] || {}
  set.call(:ulimits, host_config['Ulimits'])
  set.call(:userns_mode, host_config['UsernsMode'])
  uts_mode = host_config['UTSMode']
  set.call(:uts_mode, uts_mode == 'private' ? '' : uts_mode)
  set.call(:volumes_from, host_config['VolumesFrom'])
  ip = ip_address_from_container(info)
  set.call(:ip_address, ip)
  # Log settings are only reported by inspect and were previously ignored on
  # existing containers, so changing them was a silent no-op.
  log_config = host_config['LogConfig'] || {}
  # The host default is what the resource encodes as nil.
  set.call(:log_driver, log_config['Type'] == default_log_driver ? nil : log_config['Type'])

  if ::ENV['PODMAN_DEBUG_CURRENT']
    new_resource.class.properties.each do |name, opts|
      next unless opts.desired_state?
      a = begin
        new_resource.send(name)
          rescue StandardError
            next
      end
      b = begin
        send(name)
          rescue StandardError
            next
      end
      Chef::Log.warn("DIFF #{name}: new=#{a.inspect} cur=#{b.inspect}") if a != b
    end
  end
  log_opts(log_config['Config'] || {})
end

action :run do
  validate_container_create
  call_action(:create)
  call_action(:start)
  call_action(:delete) if new_resource.autoremove
end

action :create do
  validate_container_create

  converge_if_changed do
    action_delete

    with_retries do
      new_resource.create_options = { 'flags' => container_flags(new_resource), 'image' => image_identifier }
      podman_execute!('create', *container_flags(new_resource), image_identifier, *Array(new_resource.command))
    end
  end
end

action :start do
  return if state['Restarting']
  return if state['Running']

  converge_by "starting #{new_resource.container_name}" do
    with_retries do
      if new_resource.detach
        podman_execute!('start', new_resource.container_name)
      else
        args = ['start', '--attach', new_resource.container_name]
        new_resource.timeout ? podman_execute!(*args, timeout: new_resource.timeout) : podman_execute!(*args)
      end
    end
    wait_running_state(new_resource.container_name, true) if new_resource.detach
  end
end

action :stop do
  return unless state['Running']
  kill_after = new_resource.kill_after
  converge_by "stopping #{new_resource.container_name}#{kill_after ? " (will kill after #{kill_after}s)" : ''}" do
    args = ['stop']
    args.push('--time', kill_after.to_s) if kill_after
    args << new_resource.container_name
    with_retries { podman_execute!(*args) }
    wait_running_state(new_resource.container_name, false)
  end
end

action :kill do
  return unless state['Running']
  converge_by "killing #{new_resource.container_name}" do
    with_retries { podman_execute!('kill', '--signal', new_resource.signal, new_resource.container_name) }
  end
end

action :run_if_missing do
  return if current_resource
  call_action(:run)
end

action :pause do
  return unless current_resource
  return if state['Paused']
  converge_by "pausing #{new_resource.container_name}" do
    with_retries { podman_execute!('pause', new_resource.container_name) }
  end
end

action :unpause do
  return unless current_resource
  return unless state['Paused']
  converge_by "unpausing #{new_resource.container_name}" do
    with_retries { podman_execute!('unpause', new_resource.container_name) }
  end
end

action :restart do
  converge_by "restarting #{new_resource.container_name}" do
    if current_resource
      args = ['restart']
      args.push('--time', new_resource.kill_after.to_s) if new_resource.kill_after
      args << new_resource.container_name
      with_retries { podman_execute!(*args) }
    else
      call_action(:run)
    end
  end
end

action :reload do
  converge_by "reloading #{new_resource.container_name}" do
    with_retries { podman_execute!('kill', '--signal', new_resource.reload_signal, new_resource.container_name) }
  end
end

action :redeploy do
  validate_container_create

  should_create = state['Running'] == false && state['StartedAt'].to_s.start_with?('0001-01-01')
  call_action(:delete)
  call_action(should_create ? :create : :run)
end

action :delete do
  return unless current_resource
  call_action(:unpause)
  call_action(:stop)
  converge_by "deleting #{new_resource.container_name}" do
    args = ['rm']
    args << '--force' if new_resource.force
    args << '--volumes' if new_resource.remove_volumes
    args << new_resource.container_name
    with_retries { podman_execute!(*args) }
  end
end

action :remove do
  call_action(:delete)
end

action :commit do
  converge_by "committing #{new_resource.container_name}" do
    with_retries do
      podman_execute!('commit', new_resource.container_name, image_identifier)
    end
  end
end

action :export do
  raise "Please set outfile property on #{new_resource.container_name}" if new_resource.outfile.nil?

  # An existing archive is left alone, so a converge stays idempotent; `force`
  # rewrites it.
  return if ::File.exist?(new_resource.outfile) && !new_resource.force

  # The export needs a container; create it when the recipe only asks for one.
  call_action(:create) unless current_resource

  # `podman export --output` does not create missing directories.
  outfile_dir = ::File.dirname(new_resource.outfile)
  if ::File.absolute_path(outfile_dir) == outfile_dir
    directory outfile_dir do
      recursive true
    end
  end

  converge_by "exporting #{new_resource.container_name}" do
    with_retries { podman_execute!('export', '--output', new_resource.outfile, new_resource.container_name) }
  end
end

action_class do
  include PodmanCookbook::Helpers::Container

  def image_identifier
    podman_image_identifier(new_resource.repo, new_resource.tag)
  end

  def validate_container_create
    if new_resource.property_is_set?(:restart_policy) &&
       !%w(no always unless-stopped on-failure).include?(new_resource.restart_policy)
      raise Chef::Exceptions::ValidationFailed, 'restart_policy must be either no, always, unless-stopped, or on-failure.'
    end

    if new_resource.autoremove && new_resource.property_is_set?(:restart_policy) && new_resource.restart_policy != 'no'
      raise Chef::Exceptions::ValidationFailed, 'Conflicting options restart_policy and autoremove.'
    end

    if new_resource.detach &&
       (new_resource.attach_stderr || new_resource.attach_stdin || new_resource.attach_stdout || new_resource.stdin_once)
      raise Chef::Exceptions::ValidationFailed, 'Conflicting options detach, attach_stderr, attach_stdin, attach_stdout, stdin_once.'
    end

    if new_resource.network_mode == 'host' &&
       (!(new_resource.hostname.nil? || new_resource.hostname.empty?) ||
         !(new_resource.mac_address.nil? || new_resource.mac_address.empty?))
      raise Chef::Exceptions::ValidationFailed, 'Cannot specify hostname or mac_address when network_mode is host.'
    end

    # Docker uses the literal `container`; Podman uses `container:<name>`.
    if new_resource.network_mode.to_s.start_with?('container') &&
       (!(new_resource.hostname.nil? || new_resource.hostname.empty?) ||
         !Array(new_resource.dns).empty? ||
         !Array(new_resource.dns_search).empty? ||
         !(new_resource.mac_address.nil? || new_resource.mac_address.empty?) ||
         !Array(new_resource.extra_hosts).empty? ||
         !new_resource.exposed_ports.empty? ||
         !new_resource.port_bindings.empty? ||
         new_resource.publish_all_ports == true ||
         !new_resource.port.nil?)
      raise Chef::Exceptions::ValidationFailed, 'Cannot specify hostname, dns, dns_search, mac_address, extra_hosts, exposed_ports, port_bindings, publish_all_ports, port when network_mode is container.'
    end
  end

  def call_action(action)
    send("action_#{action}")
    load_current_resource
  end

  def state
    current_resource ? container_state(new_resource.container_name) : {}
  end
end
