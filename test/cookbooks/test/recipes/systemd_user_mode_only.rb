# frozen_string_literal: true

user 'chef' do
  home '/home/chef'
  shell '/bin/bash'
  action :create
end

podman_service_manager_systemd 'rootless' do
  user_mode true
  user 'chef'
  action :start
end
