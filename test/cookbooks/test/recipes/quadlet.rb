# frozen_string_literal: true

podman_quadlet 'chef-test' do
  content <<~UNIT
    [Unit]
    Description=Chef test container

    [Container]
    Image=docker.io/library/busybox:latest
    Exec=sleep 300

    [Install]
    WantedBy=default.target
  UNIT
  action :create
end

podman_quadlet 'chef-test' do
  action :enable
end

podman_quadlet 'chef-custom' do
  content <<~UNIT
    [Container]
    ContainerName=custom-name
    Image=docker.io/library/busybox:latest
    Exec=sleep 300
  UNIT
  action :create
end

podman_quadlet 'chef-test' do
  action :start
end

podman_quadlet 'chef-test' do
  action :stop
end

podman_quadlet 'chef-test' do
  action :delete
end

podman_quadlet 'chef-net' do
  type 'network'
  content <<~UNIT
    [Network]
    Subnet=10.89.0.0/24
  UNIT
  action :create
end

podman_quadlet 'chef-net' do
  type 'network'
  action :start
end

podman_quadlet 'chef-template' do
  instance_name 'one'
  content <<~UNIT
    [Container]
    Image=docker.io/library/busybox:latest
    Exec=sleep 300
  UNIT
  action :create
end

podman_quadlet 'chef-template' do
  instance_name 'one'
  action :start
end
