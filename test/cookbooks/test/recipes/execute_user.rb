# frozen_string_literal: true

user 'podman' do
  home '/home/podman'
  shell '/bin/bash'
  manage_home true
  action :create
end

# Podman refuses to run when its config directory belongs to someone else, and
# `manage_home` does not touch a home directory that already exists.
directory '/home/podman' do
  owner 'podman'
  group 'podman'
  recursive true
end

execute 'claim /home/podman' do
  command ['chown', '-R', 'podman:podman', '/home/podman']
  not_if 'sh -c "test -z \"$(find /home/podman ! -user podman -print -quit)\""'
end

# Rootless Podman picks the systemd cgroup manager and needs the user's
# manager and runtime directory for it; both only exist with lingering, because
# the daemon is started outside a login session.
execute 'enable lingering for podman' do
  command %w(loginctl enable-linger podman)
  not_if 'sh -c "loginctl show-user podman --property=Linger | grep -q Linger=yes"'
end

podman_service_manager_execute 'rootless' do
  user_mode true
  user 'podman'
  # The bundled crun is static and cannot do systemd cgroups, and the user's
  # manager needs a moment after the fresh user appears; cgroupfs keeps the
  # daemon independent of it.
  cgroup_manager 'cgroupfs'
  action :start
end
