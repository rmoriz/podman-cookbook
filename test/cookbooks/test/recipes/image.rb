# frozen_string_literal: true

file '/tmp/Dockerfile' do
  content <<~DOCKERFILE
    FROM busybox
    RUN echo built
  DOCKERFILE
end

podman_image 'busybox' do
  action :pull
end

podman_image 'alpine' do
  tag 'latest'
  action :pull_if_missing
end

podman_image 'test-build' do
  source '/tmp/Dockerfile'
  action :build_if_missing
end

podman_image 'busybox' do
  destination '/tmp/busybox.tar'
  action :save
end

podman_image 'busybox-loaded' do
  source '/tmp/busybox.tar'
  action :load
end

podman_image 'busybox-imported' do
  source '/tmp/busybox.tar'
  action :import
end

# Docker Hub rejects anonymous pushes, so the push goes to a local registry.
podman_container 'image-registry' do
  repo 'registry'
  port_bindings '5003:5000'
  action :run
end

# Podman talks to a registry over https unless the registry is marked insecure.
file '/etc/containers/registries.conf.d/50-chef-test-registry.conf' do
  content <<~TOML
    [[registry]]
    location = "127.0.0.1:5003"
    insecure = true
  TOML
end

execute 'wait for the local registry' do
  # The substitution is escaped, so the outer shell does not expand it into a
  # multi-line word list.
  command 'sh -c "for i in \$(seq 30); do curl -sf http://127.0.0.1:5003/v2/ && exit 0; sleep 1; done; exit 1"'
  not_if 'curl -sf http://127.0.0.1:5003/v2/'
end

podman_tag 'busybox' do
  target_tag 'latest'
  to_repo '127.0.0.1:5003/busybox'
  to_tag 'pushed'
  action :tag
end

podman_image '127.0.0.1:5003/busybox' do
  tag 'pushed'
  tls_verify false
  action :push
end

podman_tag 'busybox' do
  target_tag 'latest'
  to_repo 'busybox'
  to_tag 'chef-test'
  action :tag
end

podman_image 'busybox' do
  tag 'chef-test'
  action :remove
  force true
end
