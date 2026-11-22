# frozen_string_literal: true

podman_volume 'chef-test-volume' do
  driver 'local'
  opts('type' => 'none', 'o' => 'bind', 'device' => '/srv')
  action :create
end

podman_volume 'chef-test-volume' do
  action :remove
end

podman_volume_prune 'prune' do
  with_label 'chef=true'
  action :prune
end
