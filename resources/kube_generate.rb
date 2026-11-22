# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_kube_generate
provides :podman_kube_generate

# Renders a container, pod or volume into Kubernetes YAML.
property :type, %w(container pod volume), default: 'container', desired_state: false
property :source, String, name_property: true
property :destination, String
property :kind, %w(pod deployment daemonset job)
property :replicas, Integer
property :service, [true, false], default: false
property :podman_only, [true, false], default: false

action :generate do
  if new_resource.replicas && new_resource.kind != 'deployment'
    raise Chef::Exceptions::ValidationFailed, 'replicas is only valid with kind deployment'
  end

  # `podman kube generate --filename` does not create missing directories.
  if new_resource.destination
    destination_dir = ::File.dirname(new_resource.destination)
    if ::File.absolute_path(destination_dir) == destination_dir
      directory destination_dir do
        recursive true
      end
    end
  end

  # `podman kube generate` addresses its object by name and infers whether it
  # is a container, pod or volume, so `type` is informational only.
  args = %w(kube generate)
  args.push('--type', new_resource.kind) if new_resource.kind
  args.push('--replicas', new_resource.replicas.to_s) if new_resource.replicas
  args << '--service' if new_resource.service
  args << '--podman-only' if new_resource.podman_only
  args << new_resource.source

  # Generating to stdout instead of `--filename` keeps the run idempotent:
  # `--filename` refuses to overwrite an existing file.
  result = podman_execute!(*args)
  # The generation timestamp and the allocated node port change on every run and
  # carry no information, so leaving them out keeps the written file stable.
  rendered = result.stdout
                   .gsub(/^ *creationTimestamp:.*\n/, '')
                   .gsub(/^ *nodePort:.*\n/, '')

  if new_resource.destination
    file new_resource.destination do
      content rendered
      mode '0644'
    end
  else
    converge_by "generating Kubernetes YAML for #{new_resource.type} #{new_resource.source}" do
      Chef::Log.info(rendered)
    end
  end
end
