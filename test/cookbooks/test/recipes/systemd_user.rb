# frozen_string_literal: true

# The service manager creates the socket group `podman`; `useradd` would try to
# create a group of the same name and fail without `gid`, so the group exists
# first.
group 'podman' do
  system true
end

user 'podman' do
  gid 'podman'
  home '/home/podman'
  shell '/bin/bash'
  action :create
end

podman_service_manager_systemd 'rootless' do
  user_mode true
  user 'podman'
  action :start
end
