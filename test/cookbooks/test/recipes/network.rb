# frozen_string_literal: true

podman_network 'chef-test' do
  subnet '10.89.0.0/24'
  gateway '10.89.0.1'
  driver 'bridge'
  ipam_driver 'host-local'
  labels 'owner' => 'chef'
  auxiliary_addresses 'dns' => '10.89.0.53'
  action :create
end

podman_image 'busybox' do
  action :pull
end

podman_container 'networked' do
  repo 'busybox'
  command 'sleep 300'
  network_mode 'chef-test'
  action :run
end

podman_network 'chef-test' do
  container 'networked'
  action :disconnect
end

podman_network 'chef-test' do
  container 'networked'
  ip '10.89.0.20'
  action :connect
end

# The connected container keeps the network alive for the verifier.
