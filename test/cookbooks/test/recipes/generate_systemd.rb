# frozen_string_literal: true

podman_container 'templated' do
  repo 'busybox'
  command 'sleep 300'
  action :create
end

podman_generate_systemd 'templated' do
  template true
  new_unit false
  start_timeout 30
  stop_timeout 45
  restart_policy 'on-failure'
  restart_sec 5
  requires %w(network-online.target)
  no_header true
  destination '/tmp/generated-units'
  action :create
end
