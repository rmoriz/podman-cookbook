# frozen_string_literal: true

unified_mode true
use '_partial/_base'
use '_partial/_logging'
use '_partial/_service_base'

resource_name :podman_service_manager_systemd
provides :podman_service_manager_systemd
provides :podman_service_manager

action :start do
  if new_resource.user_mode && new_resource.user.to_s.empty?
    raise Chef::Exceptions::ValidationFailed, 'user_mode needs a user'
  end

  # The unit templates notify daemon-reload immediately, so the user manager
  # has to be reachable before the first of them converges.
  ensure_user_manager(new_resource.user) if new_resource.user_mode

  enable_forwarding if new_resource.ipv4_forward || new_resource.ipv6_forward

  # The socket unit names this group, but not every installation creates it.
  group new_resource.group do
    system true
    append true
    not_if { new_resource.group.to_s.empty? }
  end

  directory '/usr/local/libexec' do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
  end

  # The readiness guard needs curl when TLS is configured.
  package 'curl' if podman_tls_cert

  template podman_wait_ready do
    source 'default/podman-wait-ready.erb'
    cookbook 'podman'
    owner 'root'
    group 'root'
    mode '0755'
    variables(
      podman_bin: new_resource.podman_bin,
      podman_uri: podman_service_uri,
      podman_socket: podman_socket_path,
      podman_tls_cert: podman_tls_cert,
      podman_tls_key: podman_tls_key,
      service_timeout: new_resource.service_timeout
    )
  end

  directory containers_conf_dir do
    owner new_resource.user || 'root' if new_resource.user_mode
    group new_resource.user || 'root' if new_resource.user_mode
    recursive true
  end

  template containers_conf_file do
    source 'service/containers.conf.erb'
    cookbook 'podman'
    owner new_resource.user || 'root' if new_resource.user_mode
    group new_resource.user || 'root' if new_resource.user_mode
    mode '0644'
    variables(resource: new_resource, log_size_max: containers_log_size_max(new_resource))
  end

  if new_resource.insecure_registry || new_resource.registry_mirror
    directory ::File.dirname(podman_registries_conf_file) do
      owner new_resource.user || 'root' if new_resource.user_mode
      group new_resource.user || 'root' if new_resource.user_mode
      recursive true
    end

    file podman_registries_conf_file do
      content podman_registries_conf
      owner new_resource.user || 'root' if new_resource.user_mode
      group new_resource.user || 'root' if new_resource.user_mode
      mode '0644'
    end
  end

  directory podman_unit_dir do
    owner new_resource.user || 'root' if new_resource.user_mode
    group new_resource.user || 'root' if new_resource.user_mode
    recursive true
  end

  # systemd binds the socket before anything else starts, so the directory the
  # ListenStream points at has to exist by then. The package ships a tmpfiles
  # entry for it, a static install does not.
  socket_directory = new_resource.user_mode ? podman_socket_path.sub(%r{/[^/]+\z}, '') : '/run/podman'
  directory socket_directory do
    owner new_resource.user || 'root' if new_resource.user_mode
    group new_resource.user || 'root' if new_resource.user_mode
    mode '0755'
    recursive true
  end

  file "/etc/tmpfiles.d/podman-cookbook-#{podman_name}.conf" do
    content "d #{socket_directory} 0755 #{new_resource.user_mode ? new_resource.user : 'root'} #{new_resource.group || 'root'} -\n"
    mode '0644'
  end

  template ::File.join(podman_unit_dir, "#{podman_name}.socket") do
    source 'systemd/podman.socket.erb'
    cookbook 'podman'
    owner new_resource.user || 'root' if new_resource.user_mode
    group new_resource.user || 'root' if new_resource.user_mode
    mode '0644'
    variables(
      podman_name: podman_name,
      socket_user: new_resource.user_mode ? new_resource.user || 'root' : 'root',
      group: new_resource.group,
      systemd_socket_opts: Array(new_resource.systemd_socket_opts).join("\n")
    )
    notifies :run, "execute[podman systemctl daemon-reload #{podman_name}]", :immediately
  end

  template ::File.join(podman_unit_dir, "#{podman_name}.service") do
    source 'systemd/podman.service.erb'
    cookbook 'podman'
    owner new_resource.user || 'root' if new_resource.user_mode
    group new_resource.user || 'root' if new_resource.user_mode
    mode '0644'
    variables(
      podman_name: podman_name,
      podman_bin: new_resource.podman_bin,
      podman_flags: podman_global_flags.join(' '),
      tls_server_cert: podman_tls_cert,
      tls_server_key: podman_tls_key,
      tls_ca_cert: new_resource.tls_ca_cert,
      log_level: new_resource.log_level,
      user_mode: new_resource.user_mode,
      env_vars: new_resource.env_vars,
      http_proxy: new_resource.http_proxy,
      https_proxy: new_resource.https_proxy,
      no_proxy: new_resource.no_proxy,
      api_cors_header: new_resource.api_cors_header,
      service_timeout: new_resource.service_timeout,
      ipv4_forward: new_resource.ipv4_forward,
      ipv6_forward: new_resource.ipv6_forward,
      systemd_opts: Array(new_resource.systemd_opts).join("\n")
    )
    notifies :run, "execute[podman systemctl daemon-reload #{podman_name}]", :immediately
    notifies :run, "execute[podman systemctl restart #{podman_name}]", :immediately
  end

  execute "podman systemctl daemon-reload #{podman_name}" do
    command [*podman_systemctl, 'daemon-reload'].shelljoin
    environment systemctl_environment
    # Root cannot talk to another user's session bus, so the user-mode calls
    # run as that user.
    user new_resource.user if new_resource.user_mode
    group new_resource.user if new_resource.user_mode
    action :nothing
  end

  execute "podman systemctl restart #{podman_name}" do
    command [*podman_systemctl, 'try-restart', "#{podman_name}.service"].shelljoin
    environment systemctl_environment
    user new_resource.user if new_resource.user_mode
    group new_resource.user if new_resource.user_mode
    action :nothing
  end

  if new_resource.user_mode
    execute 'enable and start podman socket (user)' do
      command [*podman_systemctl, 'enable', '--now', "#{podman_name}.socket"].shelljoin
      environment systemctl_environment
      user new_resource.user if new_resource.user
      # Checking the enablement symlink instead of `is-enabled` keeps the guard
      # off the session bus, which is not always reachable.
      not_if { ::File.symlink?(::File.join(podman_unit_dir, 'sockets.target.wants', "#{podman_name}.socket")) }
    end
  else
    # WantedBy=sockets.target alone does not enable the socket, only the
    # package's preset does that.
    service "#{podman_name}.socket" do
      provider Chef::Provider::Service::Systemd
      action :enable
    end

    service podman_name do
      provider Chef::Provider::Service::Systemd
      supports status: true
      action [:enable, :start]
      retries 1
    end
  end
end

action :stop do
  if new_resource.user_mode
    execute 'stop and disable podman socket (user)' do
      command [*podman_systemctl, 'disable', '--now', "#{podman_name}.socket"].shelljoin
      environment systemctl_environment
      user new_resource.user if new_resource.user
      only_if { shell_out([*podman_systemctl, 'is-active', "#{podman_name}.socket"].shelljoin, environment: systemctl_environment, user: new_resource.user).exitstatus.zero? }
    end
  else
    service podman_name do
      provider Chef::Provider::Service::Systemd
      supports status: true
      action [:disable, :stop]
    end
    service "#{podman_name}.socket" do
      provider Chef::Provider::Service::Systemd
      action [:disable, :stop]
    end
  end
end

action :restart do
  action_stop
  action_start
end

action_class do
  include PodmanCookbook::Helpers::Service

  # Without lingering the user manager stops the socket as soon as the last
  # session ends, and `systemctl --user` has no bus to talk to at all.
end
