# frozen_string_literal: true

podman_container 'web' do
  repo 'busybox'
  command %w(sleep 300)
  port_bindings '80:80'
  action :create
end

podman_kube_generate 'web' do
  kind 'deployment'
  replicas 2
  destination '/tmp/web.yaml'
  service true
  action :generate
end
