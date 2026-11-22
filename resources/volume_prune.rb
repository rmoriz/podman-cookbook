# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_volume_prune
provides :podman_volume_prune

include PodmanCookbook::Helpers::Json

property :read_timeout, Integer, default: 120, desired_state: false
property :all, [true, false], default: false
property :with_label, String
property :without_label, String

action :prune do
  args = ['volume', 'prune', '--force']
  args << '--all' if new_resource.all && all_supported?
  filters = volume_prune_filters(new_resource)
  args.push('--filter', filters.join(',')) unless filters.empty?
  result = with_retries { podman_execute!(*args, timeout: new_resource.read_timeout) }
  Chef::Log.info(result.stdout)
  converge_by('pruning volumes') {} if prune_removed?(result.stdout)
end

action_class do
  # Podman below 5 knows no `--all` and only prunes anonymous volumes.
  def all_supported?
    @all_supported ||= podman_shell_out('volume', 'prune', '--help').stdout.to_s.include?('--all')
  end
end
