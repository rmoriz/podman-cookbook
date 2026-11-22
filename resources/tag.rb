# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_tag
provides :podman_tag

property :target_repo, String, name_property: true
property :target_tag, String, default: 'latest'
property :to_repo, String
property :to_tag, String, default: 'latest'
property :force, [true, false], default: false, desired_state: false

action_class do
  # Retagging to the image it already points at is a no-op.
  def same_image?(target, destination)
    return false unless podman_image_exists?(destination)

    image_id(target) == image_id(destination)
  end

  def image_id(reference)
    podman_shell_out('image', 'inspect', '--format', '{{.Id}}', reference).stdout.strip
  end
end

action :tag do
  raise Chef::Exceptions::ValidationFailed, 'podman_tag needs a to_repo' if new_resource.to_repo.to_s.empty?

  target = podman_image_identifier(new_resource.target_repo, new_resource.target_tag)
  destination = podman_image_identifier(new_resource.to_repo, new_resource.to_tag)

  # Without force an existing destination is left alone, whatever it points at.
  return if !new_resource.force && podman_image_exists?(destination)
  return if same_image?(target, destination)
  converge_by "update #{target} to #{destination}" do
    podman_execute!('tag', target, destination)
  end
end
