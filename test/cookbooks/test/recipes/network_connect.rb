# frozen_string_literal: true

podman_network 'chef-connect' do
  container 'networked'
  ip '10.89.0.20'
  ip6 'fd00::20'
  action :connect
end
