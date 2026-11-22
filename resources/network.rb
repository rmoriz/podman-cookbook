# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_network
provides :podman_network

include PodmanCookbook::Helpers::Network

property :auxiliary_addresses, [String, Array, nil], coerce: proc { |v| coerce_auxiliary_addresses(v) }
property :container, String, desired_state: false
property :driver, String
property :driver_opts, PartialHashType
property :enable_ipv6, [true, false], default: false
property :gateway, [String, Array, nil], coerce: proc { |v| coerce_gateway(v) }
property :id, String, desired_state: false
property :internal, [true, false], default: false
property :ip_range, [String, Array, nil], coerce: proc { |v| coerce_string_or_array(v) }
property :ipam_driver, String
property :force, [true, false], default: false, desired_state: false
property :network_name, String, name_property: true
property :subnet, [String, Array, nil], coerce: proc { |v| coerce_string_or_array(v) }
property :ip, String
property :ip6, String
property :dns_disabled, [true, false], default: false
property :labels, [String, Array, Hash], default: {}, coerce: proc { |v| coerce_network_labels(v) }

alias_method :aux_address, :auxiliary_addresses

load_current_value do |_new_resource|
  info = podman_inspect('network', network_name)
  current_value_does_not_exist! unless info

  driver info['driver'] || info['Driver']
  internal !!(info.key?('internal') ? info['internal'] : info['Internal'])
  enable_ipv6 !!(info.key?('ipv6_enabled') ? info['ipv6_enabled'] : info['EnableIPv6'])
  ipam_driver info.dig('ipam_options', 'driver') || info['ipam_driver'] || info['IPAMDriver']
  driver_opts info['options'] || info['Options']
  subnets = info['subnets'] || info['Subnets'] || []
  subnet subnets.map { |entry| entry['subnet'] || entry['Subnet'] }.compact
  gateway subnets.map { |entry| entry['gateway'] || entry['Gateway'] }.compact
  dns_enabled = info.key?('dns_enabled') ? info['dns_enabled'] : info['DNSEnabled']
  dns_disabled !dns_enabled unless dns_enabled.nil?
  network_labels = info['labels'] || info['Labels'] || {}
  aux = network_labels.select { |key, _| key.start_with?('aux_address_') }.values
  auxiliary_addresses aux unless aux.empty?
  labels network_labels.reject { |key, _| key.start_with?('aux_address_') }
end

action :create do
  converge_if_changed do
    # Recreating a network has to detach the containers using it, so drop them
    # together with the old network.
    with_retries { podman_execute!('network', 'rm', '--force', new_resource.network_name) } if current_resource
    with_retries do
      podman_execute!('network', 'create', *network_flags(new_resource), new_resource.network_name)
    end
  end
end

action :delete do
  return unless current_resource
  converge_by "deleting #{new_resource.network_name}" do
    with_retries { podman_execute!('network', 'rm', *(['--force'] if new_resource.force), new_resource.network_name) }
  end
end

action :remove do
  action_delete
end

action :connect do
  raise Chef::Exceptions::ValidationFailed, 'Container id or name is required for action :connect' unless new_resource.container
  raise "Cannot connect to #{new_resource.network_name}: network does not exist" unless current_resource

  networks = container_networks(new_resource.container)
  attached = networks[new_resource.network_name]

  if attached
    current_ip = strip_prefix(attached['IPAddress'])
    current_ip6 = strip_prefix(attached['GlobalIPv6Address'])
    must_disconnect = (property_is_set?(:ip) && current_ip != strip_prefix(new_resource.ip)) ||
                      (property_is_set?(:ip6) && current_ip6 != strip_prefix(new_resource.ip6))
    if must_disconnect
      converge_by("disconnecting #{new_resource.container} to reattach it with the correct IP config") do
        with_retries { podman_execute!('network', 'disconnect', new_resource.network_name, new_resource.container) }
      end
      attached = nil
    end
  end

  return if attached

  converge_by("connect #{new_resource.container}") do
    args = %w(network connect)
    args.push('--ip', new_resource.ip) if property_is_set?(:ip)
    args.push('--ip6', new_resource.ip6) if property_is_set?(:ip6)
    args.push(new_resource.network_name, new_resource.container)
    with_retries { podman_execute!(*args) }
  end
end

action :disconnect do
  raise Chef::Exceptions::ValidationFailed, 'Container id or name is required for action :disconnect' unless new_resource.container
  unless current_resource
    Chef::Log.warn("Cannot disconnect from #{new_resource.network_name}: network does not exist")
    return
  end

  return unless container_networks(new_resource.container).key?(new_resource.network_name)

  converge_by("disconnect #{new_resource.container}") do
    with_retries { podman_execute!('network', 'disconnect', new_resource.network_name, new_resource.container) }
  end
end

action_class do
  include PodmanCookbook::Helpers::Network

  # Podman reports bare addresses while `--ip` also accepts CIDR notation.
  def strip_prefix(value)
    value.to_s.split('/').first
  end
end
