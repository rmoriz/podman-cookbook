# frozen_string_literal: true

podman_image 'busybox' do
  action :pull
end

podman_tag 'busybox' do
  to_repo 'registry.example.com/busybox'
  to_tag 'chef-test'
  force true
  action :tag
end
