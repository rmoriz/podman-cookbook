# frozen_string_literal: true

podman_image 'busybox' do
  action :pull
end

podman_pod 'chef-test-pod' do
  publish '8080:80'
  restart_policy 'always'
  action :create
end

podman_container 'pod-member' do
  repo 'busybox'
  command 'sleep 300'
  pod 'chef-test-pod'
  action :run
end

podman_pod 'chef-test-pod' do
  action :start
end

podman_pod 'chef-test-pod' do
  action :pause
end

podman_pod 'chef-test-pod' do
  action :unpause
end

podman_pod 'chef-test-pod' do
  action :restart
end

podman_pod 'chef-test-pod' do
  action :kill
end

podman_pod 'chef-test-pod' do
  action :stop
end

podman_container 'pod-member' do
  action :delete
end

podman_pod 'chef-test-pod' do
  action :delete
end
