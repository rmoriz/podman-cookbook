# frozen_string_literal: true

user 'chef' do
  action :create
end

podman_container 'web' do
  repo 'busybox'
  command 'sleep 300'
  action :create
end

podman_generate_systemd 'web' do
  user_mode true
  user 'chef'
  action :create
end
