# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_volume
provides :podman_volume

property :driver, String
property :opts, Hash
property :volume_name, String, name_property: true

load_current_value do |_new_resource|
  info = podman_inspect('volume', volume_name)
  current_value_does_not_exist! unless info
  driver info['Driver'] || info['driver']
  opts info['Options'] || info['options']
end

action :create do
  if current_resource
    return if volume_matches?

    # Podman cannot change a driver or its options in place, and there is no
    # `--force`, so the volume has to go and come back.
    converge_by "recreating volume #{new_resource.volume_name}" do
      podman_execute!('volume', 'rm', new_resource.volume_name)
      create_volume
    end
  else
    converge_by "creating volume #{new_resource.volume_name}" do
      create_volume
    end
  end
end

action :remove do
  return unless current_resource
  converge_by "removing volume #{new_resource.volume_name}" do
    podman_execute!('volume', 'rm', new_resource.volume_name)
  end
end

action_class do
  def create_volume
    args = %w(volume create)
    args.push('--driver', new_resource.driver) if new_resource.driver
    new_resource.opts&.each { |key, value| args.push('--opt', "#{key}=#{value}") }
    args << new_resource.volume_name
    podman_execute!(*args)
  end

  # Only compare what the recipe actually set, so an unmanaged driver or extra
  # options do not look like drift.
  def volume_matches?
    return true unless new_resource.property_is_set?(:driver) || new_resource.property_is_set?(:opts)

    driver_ok = !new_resource.driver || current_resource.driver == new_resource.driver
    opts_ok = !new_resource.opts || (current_resource.opts || {}) == new_resource.opts
    driver_ok && opts_ok
  end
end
