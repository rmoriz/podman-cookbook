# frozen_string_literal: true

require 'shellwords'
require 'json'
require 'etc'

module PodmanCookbook
  module Helpers
    # Shared command construction and execution. Every resource talks to the
    # Podman CLI through this module so rootless operation, remote connections
    # and TLS are handled in exactly one place.
    module Base
      DEFAULT_PODMAN_BIN = '/usr/bin/podman'

      # `load_current_value` runs on the (cloned) resource itself, where Chef
      # only exposes `new_resource` through the enclosing provider. Resolve the
      # right object for both resources and action classes.
      def podman_resource
        respond_to?(:new_resource) ? new_resource : self
      end

      # `podman_bin` is also a resource property, so read it without passing an
      # argument (calling the setter would overwrite it with the resource).
      def podman_bin(resource = podman_resource)
        value = resource.respond_to?(:podman_bin) ? resource.podman_bin : nil
        value || DEFAULT_PODMAN_BIN
      end

      def podman_global_flags(resource = podman_resource)
        flags = []
        host = resource.respond_to?(:host) && resource.host ? Array(resource.host).first : nil
        flags << "--url=#{host}" if host
        flags << "--connection=#{resource.connection}" if resource.respond_to?(:connection) && resource.connection
        flags << "--identity=#{resource.identity_path}" if resource.respond_to?(:identity_path) && resource.identity_path
        root = resource.root if resource.respond_to?(:root)
        ready_root = root || (resource.data_root if resource.respond_to?(:data_root))
        flags << "--root=#{ready_root}" if ready_root
        flags << "--runroot=#{resource.runroot}" if resource.respond_to?(:runroot) && resource.runroot
        flags << "--storage-driver=#{resource.storage_driver}" if resource.respond_to?(:storage_driver) && resource.storage_driver
        Array(resource.storage_opts).each { |opt| flags << "--storage-opt=#{opt}" } if resource.respond_to?(:storage_opts) && resource.storage_opts
        flags << "--cgroup-manager=#{resource.cgroup_manager}" if resource.respond_to?(:cgroup_manager) && resource.cgroup_manager
        flags << '--remote' if resource.respond_to?(:remote) && resource.remote

        if host.to_s.start_with?('tcp:')
          flags << "--tls-ca=#{resource.tls_ca_cert}" if resource.respond_to?(:tls_ca_cert) && resource.tls_ca_cert
          flags << "--tls-cert=#{resource.tls_client_cert}" if resource.respond_to?(:tls_client_cert) && resource.tls_client_cert
          flags << "--tls-key=#{resource.tls_client_key}" if resource.respond_to?(:tls_client_key) && resource.tls_client_key
        end
        flags
      end

      def podman_command(*args, resource: podman_resource)
        [resource.respond_to?(:podman_bin) ? resource.podman_bin : nil, *podman_global_flags(resource), *args].flatten.compact.map(&:to_s)
      end

      def podman_environment(resource = podman_resource)
        env = {}
        if resource.respond_to?(:run_as) && resource.run_as
          begin
            passwd = ::Etc.getpwnam(resource.run_as)
            # `sudo -E` keeps the caller's XDG_CONFIG_HOME, which would point
            # at the root-owned config of the invoking user, so all of the
            # user's XDG directories are set explicitly.
            env['HOME'] = passwd.dir
            env['XDG_CONFIG_HOME'] = ::File.join(passwd.dir, '.config')
            env['XDG_DATA_HOME'] = ::File.join(passwd.dir, '.local', 'share')
            env['XDG_CACHE_HOME'] = ::File.join(passwd.dir, '.cache')
            env['XDG_RUNTIME_DIR'] ||= "/run/user/#{passwd.uid}"
            env['DBUS_SESSION_BUS_ADDRESS'] ||= "unix:path=/run/user/#{passwd.uid}/bus"
          rescue ArgumentError
            Chef::Log.warn("podman: run_as user #{resource.run_as} does not exist")
          end
        end
        env
      end

      def podman_shell_out(*args, input: nil, timeout: nil, resource: podman_resource)
        cmd = podman_command(*args, resource: resource).shelljoin
        write_timeout = resource.respond_to?(:write_timeout) ? resource.write_timeout : nil
        opts = { timeout: timeout || (input.nil? ? resource.read_timeout : write_timeout || resource.read_timeout) }
        opts[:input] = input unless input.nil?
        opts[:user] = resource.run_as if resource.respond_to?(:run_as) && resource.run_as
        env = podman_environment(resource)
        opts[:environment] = env unless env.empty?
        Chef::Log.debug("podman: #{cmd}")
        shell_out(cmd, **opts)
      end

      def podman_execute!(*args, input: nil, timeout: nil, resource: podman_resource)
        result = podman_shell_out(*args, input: input, timeout: timeout, resource: resource)
        result.error!
        result
      end

      def podman_json(*args, resource: podman_resource)
        result = podman_shell_out(*args, resource: resource)
        return [] if result.error? || result.stdout.to_s.strip.empty?
        JSON.parse(result.stdout)
      rescue JSON::ParserError
        []
      end

      def podman_inspect(kind, name, resource: podman_resource)
        data = podman_json(kind, 'inspect', '--format', 'json', name, resource: resource)
        data.is_a?(Array) ? data.first : data
      end

      def podman_object_exists?(kind, name, resource: podman_resource)
        podman_shell_out(kind, 'exists', name, resource: resource).exitstatus.zero?
      end

      def podman_image_exists?(image, resource: podman_resource)
        podman_object_exists?('image', image, resource: resource)
      end

      def podman_image_identifier(repo, tag)
        tag.to_s.start_with?('sha256:') ? "#{repo}@#{tag}" : "#{repo}:#{tag}"
      end

      # Podman prints `Deleted:` lines for removed objects and a reclaimed size.
      # A prune that removed nothing still succeeds, so the output decides
      # whether the run counts as changed.
      def prune_removed?(stdout)
        output = stdout.to_s
        output.match?(/Deleted:/) || output.match?(/reclaimed space:\s*(?!0\s*B)/i)
      end

      def with_retries
        tries = podman_resource.api_retries
        begin
          yield
        rescue Mixlib::ShellOut::ShellCommandFailed,
               Mixlib::ShellOut::CommandTimeout,
               Mixlib::ShellOut::InvalidCommandOption
          tries -= 1
          retry if tries.positive?
          raise
        end
      end
    end
  end
end
