# frozen_string_literal: true

unified_mode true
use '_partial/_base'
use '_partial/_logging'
use '_partial/_service_base'

resource_name :podman_service_manager_execute
provides :podman_service_manager_execute

action :start do
  enable_forwarding if new_resource.ipv4_forward || new_resource.ipv6_forward

  group new_resource.group do
    system true
    append true
    not_if { new_resource.group.to_s.empty? }
  end

  directory ::File.dirname(new_resource.pidfile) do
    recursive true
  end

  # The systemd manager creates this for its own copy of the readiness guard;
  # the execute manager writes its own copy there as well.
  directory ::File.dirname(podman_wait_ready) do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
  end

  # The readiness guard needs curl when TLS is configured.
  package 'curl' if podman_tls_cert

  # Rootless sockets live in a per-user runtime directory that only exists for
  # logged-in users, so the manager has to create it. logind creates that
  # directory as the user with mode 0700; when the manager pre-creates it as
  # root, logind keeps the root ownership and the user's own manager cannot
  # write into it, so it is owned the same way here.
  #
  # The socket directory itself is created by the start command, after logind
  # finished: logind wipes and re-creates the runtime directory while it sets up
  # the user's manager, which would take a directory created here with it.
  if new_resource.user_mode
    directory podman_runtime_dir do
      owner new_resource.user
      group new_resource.user
      mode '0700'
    end
  end

  # Written before anything probes it: the guards below run the script, and on a
  # fresh host it does not exist yet.
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

  # A killed manager leaves its socket behind and a new one would bind a second
  # socket under the same path while the old one is still around.
  execute "remove stale socket #{podman_socket_path}" do
    command ['rm', '-f', podman_socket_path]
    not_if podman_wait_ready
  end

  # The service has to run as the socket owner, otherwise it serves root's
  # store. The shell stays root because it writes the log and pid files.
  # `setsid` detaches the daemon from the shell that started it, so a hangup of
  # the chef-client session does not take the service down with it.
  daemon_command = "setsid #{service_start_command} >> #{new_resource.logfile} 2>&1 & echo $! > #{new_resource.pidfile}"
  start_command = daemon_command
  if new_resource.user_mode
    # `su` keeps root's environment, so the user's home and runtime directory
    # have to be set explicitly; Podman refuses a home that belongs to someone
    # else.
    runtime_dir = podman_runtime_dir
    socket_dir = ::File.dirname(podman_socket_path)
    home = podman_user_home(new_resource.user)
    # `su` keeps root's environment, so the user's home and runtime directory
    # have to be set explicitly; Podman refuses a home that belongs to someone
    # else. The runner exports `XDG_*` paths inside root's home, and Podman
    # prefers them over `HOME`, so they are pointed at the user as well.
    user_env = ['HOME', home, 'XDG_RUNTIME_DIR', runtime_dir, 'XDG_CONFIG_HOME', "#{home}/.config",
                'XDG_CACHE_HOME', "#{home}/.cache", 'XDG_DATA_HOME', "#{home}/.local/share",
                'USER', new_resource.user, 'LOGNAME', new_resource.user].each_slice(2).map { |key, value| "#{key}=#{value}" }

    # Rootless Podman picks the systemd cgroup manager and needs the user's
    # manager for it. Lingering is typically enabled right before this resource
    # runs, and logind takes a moment to bring the manager up; until then it is
    # still rewriting the runtime directory.
    start_command = [
      "touch #{new_resource.logfile} #{new_resource.pidfile}",
      "chown #{new_resource.user} #{new_resource.logfile} #{new_resource.pidfile}",
      "for i in $(seq 100); do [ -S #{runtime_dir}/systemd/private ] && break; sleep 0.1; done",
      # logind can re-create the runtime directory after the manager socket
      # already appeared, which takes the socket directory with it and leaves a
      # daemon behind that nobody can reach. Every attempt therefore re-creates
      # the directory, starts the daemon and probes it.
      'for attempt in $(seq 5); do',
      "  [ -s #{new_resource.pidfile} ] && kill $(cat #{new_resource.pidfile}) 2>/dev/null",
      "  install -d -o #{new_resource.user} -g #{new_resource.user} #{socket_dir}",
      "  su -s /bin/sh #{new_resource.user} -c '#{user_env.join(' ')} #{daemon_command}'",
      "  #{podman_wait_ready} && exit 0",
      # A failed attempt would otherwise only say that nothing answered.
      '  echo "attempt $attempt did not come up"',
      "  ps -o pid,ppid,stat,wchan:24,cmd -p \"$(cat #{new_resource.pidfile})\" || true",
      "  ls -l #{socket_dir} #{podman_socket_path} || true",
      "  tail -n 20 #{new_resource.logfile} || true",
      '  sleep 1',
      'done',
      'exit 1',
    ].join("\n")
  end

  bash "start #{podman_name}" do
    code start_command
    environment daemon_env
    # The pid file alone is not enough: another manager may have replaced the
    # socket under the still running process, which then answers nothing.
    not_if "sh -c 'test -s #{new_resource.pidfile} && kill -0 $(cat #{new_resource.pidfile}) && #{podman_wait_ready}'"
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

  execute "podman-wait-ready #{podman_name}" do
    command podman_wait_ready
    # A probe that already answers must not report a change on every converge.
    not_if podman_wait_ready
  end
end

action_class do
  include PodmanCookbook::Helpers::Service

  def service_start_command
    args = podman_command('system', 'service', '--time=0', resource: self)
    cert = podman_tls_cert
    key = podman_tls_key
    if cert
      args.push('--tls-cert', cert)
      args.push('--tls-key', key) if key
      args.push('--tls-client-ca', new_resource.tls_ca_cert) if new_resource.tls_ca_cert
    end
    args.push(podman_service_uri)
    args.shelljoin
  end
end

action :stop do
  execute "stop #{podman_name}" do
    command "kill $(cat #{new_resource.pidfile}) && rm -f #{new_resource.pidfile}"
    only_if "sh -c 'test -s #{new_resource.pidfile} && kill -0 $(cat #{new_resource.pidfile})'"
    timeout 10
  end
end

action :restart do
  action_stop
  action_start
end
