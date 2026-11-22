# frozen_string_literal: true

podman_container 'container-net-invalid' do
  repo 'busybox'
  network_mode 'container:hello-world'
  hostname 'ignored'
  action :create
end
