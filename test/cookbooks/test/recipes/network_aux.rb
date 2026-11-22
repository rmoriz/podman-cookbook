# frozen_string_literal: true

podman_network 'chef-aux' do
  subnet '10.90.0.0/24'
  gateway '10.90.0.1'
  auxiliary_addresses ['router=10.90.0.2', 'printer=10.90.0.3']
  action :create
end
