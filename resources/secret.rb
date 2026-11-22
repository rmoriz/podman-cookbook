# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_secret
provides :podman_secret

# `podman secret` is Podman-only; Docker requires an external Swarm or the
# `docker secret` command. Secrets are stored in Podman's own secret store.
property :secret_name, String, name_property: true
property :value, String, sensitive: true
property :secret_file, String
property :driver, String
property :driver_opts, Hash
property :labels, [String, Array, Hash], default: {}, coerce: proc { |v| coerce_labels(v) }
property :replace, [true, false], default: false

include PodmanCookbook::Helpers::Container

action :create do
  if secret_exists?
    # Podman never exposes the stored value, so an existing secret can only be
    # compared by its metadata. Changing only `value` therefore needs a new
    # secret name or an explicit delete.
    return unless new_resource.replace
    return if secret_matches?

    converge_by "replacing secret #{new_resource.secret_name}" do
      create_secret
    end
  else
    converge_by "creating secret #{new_resource.secret_name}" do
      create_secret
    end
  end
end

action :delete do
  return unless secret_exists?
  converge_by "deleting secret #{new_resource.secret_name}" do
    with_retries { podman_execute!('secret', 'rm', new_resource.secret_name) }
  end
end

action :remove do
  action_delete
end

action_class do
  def secret_exists?
    podman_shell_out('secret', 'exists', new_resource.secret_name).exitstatus.zero?
  end

  # Only compare metadata the recipe actually manages, so an unchanged secret
  # is not deleted and recreated on every run.
  def secret_matches?
    spec = podman_inspect('secret', new_resource.secret_name)&.fetch('Spec', nil)
    return false unless spec

    return false unless (spec['Labels'] || {}) == (new_resource.labels || {})
    driver = spec.dig('Driver', 'Name')
    return false if new_resource.driver && driver != new_resource.driver
    return false if new_resource.driver_opts && (spec.dig('Driver', 'Options') || {}) != new_resource.driver_opts

    true
  end

  def create_secret
    args = %w(secret create)
    args.push('--driver', new_resource.driver) if new_resource.driver
    new_resource.driver_opts&.each { |key, value| args.push('--driver-opts', "#{key}=#{value}") }
    new_resource.labels.each { |key, value| args.push('--label', "#{key}=#{value}") }
    # Podman below 5 fails a `--replace` that has nothing to replace with
    # `no secret data with ID`, so only hand it over for an existing secret.
    args << '--replace' if new_resource.replace && secret_exists?
    args << new_resource.secret_name

    if new_resource.value
      with_retries { podman_execute!(*args, '-', input: new_resource.value) }
    elsif new_resource.secret_file
      args << new_resource.secret_file
      with_retries { podman_execute!(*args) }
    else
      raise Chef::Exceptions::ValidationFailed, 'podman_secret needs either value or secret_file'
    end
  end
end
