# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_pod
provides :podman_pod

# Pods group containers that share a network, IPC and (optionally) PID
# namespace. This is Podman's counterpart to a Kubernetes pod and has no Docker
# equivalent.
property :pod_name, String, name_property: true
property :labels, [String, Array, Hash], default: {}, coerce: proc { |v| coerce_labels(v) }
property :infra, [true, false], default: true
property :infra_command, String
property :share, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v).sort }
property :network, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :network_aliases, [String, Array], default: [], coerce: proc { |v| Array(v) }
property :publish, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v).map { |entry| canonical_publish(entry) } }
property :dns, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :dns_search, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :hostname, String
property :ip, String
property :mac_address, String
property :add_host, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :cgroup_parent, String
property :exit_policy, String
property :restart_policy, String, default: 'no'
# Applies to the infra container and to every container later joined to the
# pod, see documentation/alternative-runtimes.md.
property :runtime, String, desired_state: false
property :replace, [true, false], default: false, desired_state: false
property :kill_timeout, Integer, desired_state: false
property :signal, String, default: 'SIGTERM', desired_state: false

include PodmanCookbook::Helpers::Container

# Host addresses that Podman fills in even when the user wrote the short form
# are dropped so `8080:80` and `0.0.0.0:8080:80` compare as the same publish.
def canonical_publish(entry)
  parts = entry.to_s.split(':')
  parts.shift if parts.size > 2 && %w(0.0.0.0 ::).include?(parts.first)
  parts.join(':')
end

def pod_publish_entries(info)
  bindings = info.dig('InfraConfig', 'PortBindings') || {}
  entries = bindings.flat_map do |container_port, hosts|
    port = container_port.split('/').first
    Array(hosts).map do |host|
      [host['HostIp'].to_s, host['HostPort'].to_s, port].reject(&:empty?).join(':')
    end
  end
  entries.map { |entry| canonical_publish(entry) }
end

def pod_network_aliases(info)
  (info.dig('InfraConfig', 'NetworkOptions') || {}).values.flatten.filter_map do |option|
    option.delete_prefix('alias=') if option.start_with?('alias=')
  end
end

def pod_infra_command(info)
  command = Array(info['CreateCommand'])
  index = command.index('--infra-command')
  return command[index + 1] if index
  command.find { |part| part.start_with?('--infra-command=') }&.split('=', 2)&.last
end

# Only load a property when the recipe asks for it. The resource has defaults
# for the other properties, so loading Podman's own defaults as well would
# report drift and recreate the pod on every run.
load_current_value do |new_resource|
  info = podman_inspect('pod', pod_name)
  current_value_does_not_exist! unless info

  labels info['Labels'] || {}
  infra info['CreateInfra'] unless info['CreateInfra'].nil?
  restart_policy(info['RestartPolicy'].to_s.empty? ? 'no' : info['RestartPolicy'])
  share Array(info['SharedNamespaces']).sort if new_resource.property_is_set?(:share)
  hostname info['Hostname'] if new_resource.property_is_set?(:hostname)
  network info.dig('InfraConfig', 'Networks') if new_resource.property_is_set?(:network)
  network_aliases pod_network_aliases(info) if new_resource.property_is_set?(:network_aliases)
  publish pod_publish_entries(info) if new_resource.property_is_set?(:publish)
  dns info.dig('InfraConfig', 'DNSServer') if new_resource.property_is_set?(:dns)
  dns_search info.dig('InfraConfig', 'DNSSearch') if new_resource.property_is_set?(:dns_search)
  add_host info.dig('InfraConfig', 'HostAdd') if new_resource.property_is_set?(:add_host)
  ip info.dig('InfraConfig', 'StaticIP') if new_resource.property_is_set?(:ip)
  mac_address info.dig('InfraConfig', 'StaticMAC') if new_resource.property_is_set?(:mac_address)
  cgroup_parent info['CgroupParent'] if new_resource.property_is_set?(:cgroup_parent)
  exit_policy info['ExitPolicy'] if new_resource.property_is_set?(:exit_policy)
  infra_command pod_infra_command(info) if new_resource.property_is_set?(:infra_command)
end

action :create do
  validate_restart_policy
  converge_if_changed do
    action_delete
    with_retries { podman_execute!('pod', 'create', *pod_flags) }
  end
end

action :start do
  return if pod_state == 'Running'
  converge_by "starting pod #{new_resource.pod_name}" do
    podman_execute!('pod', 'start', new_resource.pod_name)
  end
end

action :stop do
  return unless %w(Running Paused).include?(pod_state)
  converge_by "stopping pod #{new_resource.pod_name}" do
    args = %w(pod stop)
    args << '--time' << new_resource.kill_timeout.to_s if new_resource.respond_to?(:kill_timeout) && new_resource.kill_timeout
    args << new_resource.pod_name
    podman_execute!(*args)
  end
end

action :delete do
  return unless current_resource
  converge_by "deleting pod #{new_resource.pod_name}" do
    podman_execute!('pod', 'rm', '--force', new_resource.pod_name)
  end
end

action :remove do
  action_delete
end

action :restart do
  return if pod_state.nil?
  converge_by "restarting pod #{new_resource.pod_name}" do
    podman_execute!('pod', 'restart', new_resource.pod_name)
  end
end

action :pause do
  return if pod_state != 'Running'
  converge_by "pausing pod #{new_resource.pod_name}" do
    podman_execute!('pod', 'pause', new_resource.pod_name)
  end
end

action :unpause do
  return if pod_state != 'Paused'
  converge_by "unpausing pod #{new_resource.pod_name}" do
    podman_execute!('pod', 'unpause', new_resource.pod_name)
  end
end

action :kill do
  return unless %w(Running Paused).include?(pod_state)
  converge_by "killing pod #{new_resource.pod_name}" do
    podman_execute!('pod', 'kill', '--signal', new_resource.signal, new_resource.pod_name)
  end
end

action_class do
  include PodmanCookbook::Helpers::Container

  def pod_state
    podman_inspect('pod', new_resource.pod_name)&.fetch('State', nil)
  end

  def validate_restart_policy
    return if %w(no always on-failure unless-stopped).include?(new_resource.restart_policy)
    raise Chef::Exceptions::ValidationFailed, 'restart_policy must be no, always, on-failure or unless-stopped'
  end

  def pod_flags
    args = ['--name', new_resource.pod_name]
    new_resource.labels.each { |key, value| args.push('--label', "#{key}=#{value}") }
    args << '--infra=false' unless new_resource.infra
    args.push('--infra-command', new_resource.infra_command) if new_resource.infra_command
    args.push('--share', Array(new_resource.share).join(',')) unless Array(new_resource.share).empty?
    Array(new_resource.network).each { |net| args.push('--network', net) }
    new_resource.network_aliases.each { |a| args.push('--network-alias', a) }
    Array(new_resource.publish).each { |p| args.push('--publish', p) }
    Array(new_resource.dns).each { |d| args.push('--dns', d) }
    Array(new_resource.dns_search).each { |d| args.push('--dns-search', d) }
    args.push('--hostname', new_resource.hostname) if new_resource.hostname
    args.push('--ip', new_resource.ip) if new_resource.ip
    args.push('--mac-address', new_resource.mac_address) if new_resource.mac_address
    Array(new_resource.add_host).each { |h| args.push('--add-host', h) }
    args.push('--cgroup-parent', new_resource.cgroup_parent) if new_resource.cgroup_parent
    args.push('--exit-policy', new_resource.exit_policy) if new_resource.exit_policy
    args.push('--restart', new_resource.restart_policy)
    args.push('--runtime', new_resource.runtime) if new_resource.runtime
    args << '--replace' if new_resource.replace
    # `podman pod create` takes the name from --name only; a trailing
    # positional argument is rejected.
    args
  end
end
