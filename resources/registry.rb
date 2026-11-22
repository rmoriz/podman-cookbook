# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_registry
provides :podman_registry

property :email, String
property :password, String, sensitive: true
property :serveraddress, String, name_property: true
property :username, String
property :tls_verify, [true, false], default: true, description: 'Verify the registry certificate; false for plain-HTTP registries'

action :login do
  registry_host = parse_registry_host(new_resource.serveraddress)

  (node.run_state['podman_auth'] ||= {})[registry_host] = {
    'serveraddress' => registry_host,
    'username' => new_resource.username,
    'password' => new_resource.password,
    'email' => new_resource.email,
  }

  return if logged_in_as?(registry_host)

  converge_by "logging in to #{new_resource.serveraddress}" do
    args = ['login', '--password-stdin']
    args << '--tls-verify=false' unless new_resource.tls_verify
    args.push('--username', new_resource.username) if new_resource.username
    args << registry_host
    with_retries { podman_execute!(*args, input: new_resource.password.to_s) }
  end
end

action_class do
  # `podman login --get-login` prints the stored user and fails when there is
  # no credential for the host, so an unchanged login is not repeated.
  def logged_in_as?(registry_host)
    return false if new_resource.username.to_s.empty?
    result = podman_shell_out('login', '--get-login', registry_host)
    result.exitstatus.zero? && result.stdout.strip == new_resource.username
  end
end
