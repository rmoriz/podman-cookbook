# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_exec
provides :podman_exec

property :command, Array
property :container, String
property :container_obj, [String, nil], desired_state: false,
                                        description: 'Container name, kept for API parity with docker_exec'
# An exec session needs the container monitor to report the exit code back,
# which can take a while on a loaded or slow host.
property :timeout, Numeric, default: 180, desired_state: false
property :returns, [Integer, Array], coerce: proc { |v| Array(v) }, default: [0],
                                     description: 'Accepted exit codes. Raises when the command exits with anything else.'

alias_method :cmd, :command

action :run do
  raise Chef::Exceptions::ValidationFailed, 'podman_exec needs a container or container_obj' if exec_container.nil?

  converge_by "executing #{new_resource.command} on #{exec_container}" do
    result = with_retries do
      podman_shell_out('exec', exec_container, *Array(new_resource.command), timeout: new_resource.timeout)
    end
    Chef::Log.trace(result.stdout)
    Chef::Log.trace(result.stderr)
    unless new_resource.returns.include?(result.exitstatus)
      raise "Expected process to exit with #{new_resource.returns.join(' or ')}, but received #{result.exitstatus}"
    end
  end
end

action_class do
  def exec_container
    return new_resource.container if new_resource.container
    return unless new_resource.container_obj
    new_resource.container_obj.respond_to?(:name) ? new_resource.container_obj.name : new_resource.container_obj.to_s
  end
end
