# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_image_prune
provides :podman_image_prune

include PodmanCookbook::Helpers::Json

property :read_timeout, Integer, default: 120, desired_state: false
property :dangling, [true, false], default: true
property :prune_until, String
property :with_label, String
property :without_label, String

action :prune do
  args = ['image', 'prune', '--force']
  filters = image_prune_filters(new_resource)
  filters.each { |filter| args.push('--filter', filter) }
  result = with_retries { podman_execute!(*args, timeout: new_resource.read_timeout) }
  Chef::Log.info(result.stdout)
  converge_by('pruning images') {} if prune_removed?(result.stdout)
end
