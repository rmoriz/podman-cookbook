# frozen_string_literal: true

unified_mode true
use '_partial/_base'

require 'yaml'

resource_name :podman_kube_play
provides :podman_kube_play
provides :podman_kube

include PodmanCookbook::Helpers::Container

# Deploys a Kubernetes YAML manifest with `podman kube play`. Podman runs the
# manifest natively, without a Kubernetes API server.
property :manifest, String, name_property: true
property :manifest_content, String
property :namespace, String
property :network, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :publish, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :configmaps, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :env, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :secrets, [String, Array, nil], coerce: proc { |v| v.nil? ? nil : Array(v) }
property :service_container, [true, false], default: false,
                                            description: 'Hidden Podman flag; starts the service container before all pods'
property :userns, String
property :annotation, [String, Array], default: [], coerce: proc { |v| Array(v) }
# `podman kube play` has no `--label`, so labels are folded into the manifest.
property :labels, [String, Array, Hash], default: {}, coerce: proc { |v| coerce_labels(v) }
property :build, [true, false, nil]
property :context_dir, String
property :ip, String
property :mac_address, String
property :publish_all, [true, false], default: false
property :no_hosts, [true, false], default: false
property :replace, [true, false], default: true, description: 'Recreate existing pods of the manifest'
property :start, [true, false], default: true
property :down, [true, false], default: false
property :force, [true, false], default: false
property :quiet, [true, false], default: false

action :play do
  validate_manifest
  return action_teardown if new_resource.down
  converge_by "playing manifest #{manifest_reference}" do
    args = ['kube', 'play', *kube_flags]
    if new_resource.manifest_content
      with_retries { podman_execute!(*args, '-', input: rendered_manifest) }
    else
      with_retries { podman_execute!(*args, new_resource.manifest) }
    end
  end
end

action :teardown do
  converge_by "tearing down manifest #{manifest_reference}" do
    args = %w(kube down)
    args << '--force' if new_resource.force
    if new_resource.manifest_content && !new_resource.property_is_set?(:manifest)
      with_retries { podman_execute!(*args, '-', input: new_resource.manifest_content) }
    else
      with_retries { podman_execute!(*args, manifest_reference) }
    end
  end
end

action :delete do
  action_teardown
end

action_class do
  def validate_manifest
    return unless new_resource.manifest_content && new_resource.property_is_set?(:manifest)
    raise Chef::Exceptions::ValidationFailed, 'Set either manifest or manifest_content, not both'
  end

  def manifest_reference
    new_resource.manifest_content && !new_resource.property_is_set?(:manifest) ? 'stdin' : new_resource.manifest
  end

  # `podman kube play` has no flag for a namespace, labels, extra environment
  # variables or secrets, so fold them into the inline manifest before playing.
  def rendered_manifest
    loaded = Psych.safe_load(new_resource.manifest_content, permitted_classes: [Symbol], aliases: true)
    documents = loaded.is_a?(Array) ? loaded : [loaded]
    documents.each do |document|
      next unless document.is_a?(Hash)
      metadata = (document['metadata'] ||= {})
      metadata['namespace'] = new_resource.namespace if new_resource.namespace
      unless new_resource.labels.empty?
        metadata['labels'] = (metadata['labels'] || {}).merge(new_resource.labels)
      end
      Array(document.dig('spec', 'containers')).each { |container| apply_manifest_env(container) }
    end
    documents.unshift(*secret_documents) if new_resource.secrets
    # A manifest is a stream of documents, not a YAML sequence.
    documents.map { |document| YAML.dump(document) }.join
  end

  def apply_manifest_env(container)
    return unless container.is_a?(Hash)
    Array(new_resource.env).each do |entry|
      name, _, value = entry.partition('=')
      (container['env'] ||= []) << { 'name' => name, 'value' => value }
    end
    Array(new_resource.secrets).each do |secret|
      (container['envFrom'] ||= []) << { 'secretRef' => { 'name' => secret } }
    end
  end

  # `envFrom.secretRef` only works against a Secret in the manifest stream --
  # `podman kube play` ignores the podman secret store -- so the referenced
  # secrets are appended as Secret documents, read from the store.
  def secret_documents
    Array(new_resource.secrets).filter_map do |name|
      secret = podman_json('secret', 'inspect', '--showsecret', name).first
      next unless secret
      metadata = { 'name' => name }
      metadata['namespace'] = new_resource.namespace if new_resource.namespace
      {
        'apiVersion' => 'v1',
        'kind' => 'Secret',
        'type' => 'Opaque',
        'metadata' => metadata,
        'stringData' => secret_string_data(secret, name),
      }
    end
  end

  # Podman secrets are either `KEY=VALUE` lines (as created by `--env`) or a
  # single value that is exposed under the secret's name.
  def secret_string_data(secret, name)
    Array(secret['SecretData'] || secret['Data']).join.lines.each_with_object({}) do |line, data|
      key, separator, value = line.chomp.partition('=')
      if separator.empty?
        data[name.gsub(/[^A-Za-z0-9_]/, '_').upcase] = key
      else
        data[key] = value
      end
    end
  end

  def kube_flags
    args = []
    Array(new_resource.network).each { |n| args.push('--network', n) }
    Array(new_resource.publish).each { |p| args.push('--publish', p) }
    Array(new_resource.configmaps).each { |c| args.push('--configmap', c) }
    args.push('--service-container') if new_resource.service_container
    args.push('--userns', new_resource.userns) if new_resource.userns
    new_resource.annotation.each { |a| args.push('--annotation', a) }
    args << (new_resource.build ? '--build' : '--build=false') unless new_resource.build.nil?
    args.push('--context-dir', new_resource.context_dir) if new_resource.context_dir
    args.push('--ip', new_resource.ip) if new_resource.ip
    args.push('--mac-address', new_resource.mac_address) if new_resource.mac_address
    args << '--publish-all' if new_resource.publish_all
    args << '--no-hosts' if new_resource.no_hosts
    args << '--replace' if new_resource.replace
    args << '--start=false' unless new_resource.start
    args << '--quiet' if new_resource.quiet
    args
  end
end
