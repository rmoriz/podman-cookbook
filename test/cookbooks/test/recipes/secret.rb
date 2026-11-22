# frozen_string_literal: true

file '/tmp/chef-secret.txt' do
  content 'super-secret'
end

podman_secret 'chef-secret-file' do
  secret_file '/tmp/chef-secret.txt'
  action :create
end

podman_secret 'chef-secret-value' do
  value 'new-secret'
  action :create
end

podman_secret 'chef-secret-replaced' do
  value 'replaced-secret'
  driver 'file'
  driver_opts('path' => '/var/lib/podman/secrets')
  labels 'team' => 'ops'
  replace true
  action :create
end

podman_secret 'chef-secret-file' do
  action :delete
end

podman_secret 'chef-secret-value' do
  action :delete
end

podman_secret 'chef-secret-replaced' do
  action :delete
end
