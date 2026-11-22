# frozen_string_literal: true

podman_pod 'chef-flags-pod' do
  share %w(net ipc)
  runtime 'crun'
  action :create
end
