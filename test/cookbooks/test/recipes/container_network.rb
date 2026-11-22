# frozen_string_literal: true

# The namespace owner the next container joins.
podman_container 'hello-world' do
  repo 'busybox'
  command 'sleep 300'
  action :create
end

podman_container 'default-net' do
  repo 'busybox'
  network_mode 'default'
  action :create
end

podman_container 'container-net' do
  repo 'busybox'
  network_mode 'container:hello-world'
  action :create
end
