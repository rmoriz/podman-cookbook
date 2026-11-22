# frozen_string_literal: true

include_recipe 'test::service_tls_certs'

podman_service_manager_execute 'tls' do
  tls_client_cert '/etc/podman/client.crt'
  tls_client_key '/etc/podman/client.key'
  tls_ca_cert '/etc/podman/ca.crt'
  action :start
end
