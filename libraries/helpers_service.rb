# frozen_string_literal: true

module PodmanCookbook
  module Helpers
    module Service
      def podman_name
        resource_name = respond_to?(:new_resource) ? new_resource.name : name
        resource_name == 'default' ? 'podman' : "podman-#{resource_name}"
      end

      # Names the Docker cookbook uses; kept so docker-flavoured recipes and
      # templates keep working.
      def docker_name
        podman_name
      end

      def connect_socket
        podman_socket_path
      end

      # Podman has no containerd, so the flag only ever reads false.
      def docker_containerd
        false
      end

      # systemd expands `%t` in unit files; processes started outside systemd
      # (the execute manager) need the real path.
      def podman_socket_path(resource = podman_resource)
        if resource.respond_to?(:user_mode) && resource.user_mode
          ::File.join(podman_runtime_dir(resource), 'podman', 'podman.sock')
        else
          '/run/podman/podman.sock'
        end
      end

      def podman_runtime_dir(resource = podman_resource)
        user = resource.respond_to?(:user) ? resource.user : nil
        return '/run/user/0' if user.nil?
        "/run/user/#{::Etc.getpwnam(user).uid}"
      rescue ArgumentError
        Chef::Log.warn("podman: run_as user #{user} does not exist")
        '/run/user/0'
      end

      def podman_service_uri(resource = podman_resource)
        "unix://#{podman_socket_path(resource)}"
      end

      # `Dir.home` consults the passwd database too, but raises for an unknown
      # user; fall back to the conventional /home path in that case.
      def podman_user_home(user)
        return Etc.getpwnam(user).dir if user

        '/root'
      rescue ArgumentError
        Chef::Log.warn("podman: run_as user #{user} does not exist")
        "/home/#{user}"
      end

      def podman_unit_dir(resource = podman_resource)
        if resource.respond_to?(:user_mode) && resource.user_mode
          ::File.join(podman_user_home(resource.respond_to?(:user) ? resource.user : nil), '.config/systemd/user')
        else
          '/etc/systemd/system'
        end
      end

      def podman_conf_dir(resource = podman_resource)
        if resource.respond_to?(:user_mode) && resource.user_mode
          ::File.join(podman_user_home(resource.respond_to?(:user) ? resource.user : nil), '.config/containers/containers.conf.d')
        else
          '/etc/containers/containers.conf.d'
        end
      end

      # `log_opts` uses CLI spelling (`max-size=10m`), while containers.conf
      # wants `log_size_max` in bytes.
      def containers_log_size_max(resource = podman_resource)
        raw = if resource.log_opts.is_a?(Hash)
                resource.log_opts['max-size']
              else
                Array(resource.log_opts).grep(/^max-size=/).first&.split('=', 2)&.last
              end
        return if raw.nil?

        match = raw.to_s.match(/\A(\d+)([kmg]?)b?\z/i)
        return raw.to_s if match.nil?

        match[1].to_i * { '' => 1, 'k' => 1024, 'm' => 1024**2, 'g' => 1024**3 }[match[2].downcase]
      end

      # containers.conf has no registries table, so the settings go into a
      # registries.conf.d drop-in in the v2 format.
      def podman_registries_conf(resource = podman_resource)
        # `location` takes a bare host, so a scheme from Docker habits is
        # stripped before it is written.
        strip_scheme = ->(value) { value.to_s.sub(%r{\Ahttps?://}, '') }
        lines = ['# Managed by Chef']
        Array(resource.insecure_registry).each do |registry|
          lines.push('[[registry]]', "location = \"#{strip_scheme.call(registry)}\"", 'insecure = true')
        end
        Array(resource.registry_mirror).each do |mirror|
          lines.push('[[registry]]', 'location = "docker.io"', '[[registry.mirror]]', "location = \"#{strip_scheme.call(mirror)}\"")
        end
        "#{lines.join("\n")}\n"
      end

      def podman_registries_conf_file(resource = podman_resource)
        if resource.respond_to?(:user_mode) && resource.user_mode
          ::File.join(podman_user_home(resource.respond_to?(:user) ? resource.user : nil), '.config/containers/registries.conf.d', "90-podman-#{podman_name}.conf")
        else
          ::File.join('/etc/containers/registries.conf.d', "90-podman-#{podman_name}.conf")
        end
      end

      # `systemd_opts` are unit directives and go into the unit file, not onto
      # the systemctl command line.
      # A user manager needs lingering to survive the run, and it may not be
      # reachable right after being queued.
      def ensure_user_manager(user)
        execute "enable lingering for #{user}" do
          command ['loginctl', 'enable-linger', user]
          not_if { shell_out(['loginctl', 'show-user', user, '--property=Linger']).stdout.include?('Linger=yes') }
        end

        execute "start user manager for #{user}" do
          uid = ::Etc.getpwnam(user).uid
          command ['systemctl', 'start', "user@#{uid}.service"]
          not_if { ::File.socket?("/run/user/#{uid}/bus") }
        end
      end

      # A `systemctl --user` call needs the runtime directory and bus of the
      # user whose manager it targets.
      def systemctl_environment(resource = podman_resource)
        return {} unless resource.respond_to?(:user_mode) && resource.user_mode
        return {} unless resource.respond_to?(:user) && resource.user

        uid = ::Etc.getpwnam(resource.user).uid
        {
          'XDG_RUNTIME_DIR' => "/run/user/#{uid}",
          'DBUS_SESSION_BUS_ADDRESS' => "unix:path=/run/user/#{uid}/bus",
        }
      end

      def podman_systemctl(resource = podman_resource)
        if resource.respond_to?(:user_mode) && resource.user_mode
          ['systemctl', '--user']
        else
          ['systemctl']
        end
      end

      # `podman system service` only learned the TLS flags in Podman 5. Older
      # builds serve the socket unencrypted and reject the flags outright.
      def podman_tls_supported?
        return @podman_tls_supported unless @podman_tls_supported.nil?

        @podman_tls_supported =
          podman_shell_out('system', 'service', '--help').stdout.to_s.include?('--tls-cert')
      end

      # Podman's API server has one certificate pair. The Docker cookbook also
      # carries a client pair, so treat that as a fallback for the server pair.
      def podman_tls_cert(resource = podman_resource)
        cert = resource.tls_server_cert || resource.tls_client_cert
        return if cert.nil?

        unless podman_tls_supported?
          Chef::Log.warn("podman: this Podman build has no TLS support in `system service`, #{podman_name} serves without TLS")
          return
        end
        cert
      end

      def podman_tls_key(resource = podman_resource)
        return unless podman_tls_supported?

        resource.tls_server_key || resource.tls_client_key
      end

      # The daemon command both service managers start.
      def podman_daemon_cmd(resource = podman_resource)
        flags = respond_to?(:podman_global_flags) ? podman_global_flags : []
        [resource.podman_bin, *flags, 'system', 'service', '--time=0'].reject { |part| part.to_s.empty? }.join(' ')
      end

      def docker_daemon_cmd
        podman_daemon_cmd
      end

      # Unit-file helpers the docker templates call.
      def systemd_args
        Array(systemd_opts).join("\n")
      end

      def systemd_socket_args
        Array(systemd_socket_opts).join("\n")
      end

      def podman_install_method
        %w(debian rhel fedora suse amazon).include?(node['platform_family']) ? 'package' : 'script'
      end
    end
  end
end
