# frozen_string_literal: true

# Minimal unit, no running container behind it.
podman_quadlet 'chef-empty' do
  content <<~UNIT
    [Container]
    Image=docker.io/library/busybox:latest
  UNIT
  action :create
end
