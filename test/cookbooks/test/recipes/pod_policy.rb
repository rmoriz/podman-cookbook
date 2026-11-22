# frozen_string_literal: true

podman_pod 'chef-policy-pod' do
  restart_policy 'on-failure'
  action :create
end
