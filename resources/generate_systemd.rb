# frozen_string_literal: true

unified_mode true
use '_partial/_base'

# The destination default resolves through the shared unit-dir helper, so it
# has to be available on the resource as well as in the action class.
include PodmanCookbook::Helpers::Service

resource_name :podman_generate_systemd
provides :podman_generate_systemd

# Wraps `podman generate systemd`, the pre-Quadlet way of turning containers and
# pods into systemd units.
property :source, String, name_property: true
property :type, %w(container pod), default: 'container'
property :destination, String, default: lazy { user_mode ? podman_unit_dir(self) : '/etc/systemd/system' }
property :user_mode, [true, false], default: false
property :user, String
property :new_unit, [true, false], default: true
property :name_unit, [true, false], default: true
property :restart_policy, %w(no on-success on-failure on-abnormal on-watchdog on-abort always)
property :restart_sec, Integer
property :start_timeout, Integer
property :stop_timeout, Integer
property :no_header, [true, false], default: false
property :template, [true, false], default: false
property :separator, String, default: '-'
property :container_prefix, String
property :pod_prefix, String
property :requires, [String, Array], default: [], coerce: proc { |v| Array(v) }
property :after, [String, Array], default: [], coerce: proc { |v| Array(v) }
property :wants, [String, Array], default: [], coerce: proc { |v| Array(v) }
property :additional_env, [String, Array], default: [], coerce: proc { |v| Array(v) }
property :files, Hash, default: {}

action :create do
  # The unit templates notify daemon-reload immediately, so the user manager
  # has to be reachable before the first of them converges.
  ensure_user_manager(new_resource.user) if new_resource.user_mode && new_resource.user

  directory new_resource.destination do
    recursive true
  end

  # The command always runs because it produces the content, but only changed
  # files are reported, which keeps a converge idempotent.
  result = podman_execute!(*generate_args)
  # The header carries the generation time, which changes on every run.
  stdout = result.stdout.gsub(/^# .* \d{2}:\d{2}:\d{2} .*\d{4}$\n/, '')
  units = parse_units(stdout)

  new_resource.files.each { |filename, content| units[filename] = content }

  units.each do |filename, content|
    file ::File.join(new_resource.destination, filename) do
      content content
      mode '0644'
      notifies :run, "execute[generate-systemd daemon-reload #{new_resource.destination}]", :immediately
    end
  end

  execute "generate-systemd daemon-reload #{new_resource.destination}" do
    command reload_command
    environment systemctl_environment
    # Root cannot talk to another user's session bus, so the user-mode call
    # runs as that user.
    user new_resource.user if new_resource.user_mode
    group new_resource.user if new_resource.user_mode
    action :nothing
  end
end

action_class do
  include PodmanCookbook::Helpers::Service

  def reload_command
    [*podman_systemctl(new_resource), 'daemon-reload'].shelljoin
  end

  def generate_args
    args = %w(generate systemd)
    # `--template` implies `--new` and Podman errors out when `--new=false` is
    # passed explicitly, so only send the flag when it is wanted.
    args << '--new' if new_resource.new_unit || new_resource.template
    args << '--name' if new_resource.name_unit
    args << '--no-header' if new_resource.no_header
    args.push('--restart-policy', new_resource.restart_policy) if new_resource.restart_policy
    args.push('--restart-sec', new_resource.restart_sec.to_s) if new_resource.restart_sec
    args.push('--start-timeout', new_resource.start_timeout.to_s) if new_resource.start_timeout
    args.push('--stop-timeout', new_resource.stop_timeout.to_s) if new_resource.stop_timeout
    args << '--template' if new_resource.template
    args.push('--separator', new_resource.separator) if new_resource.separator
    args.push('--container-prefix', new_resource.container_prefix) if new_resource.container_prefix
    args.push('--pod-prefix', new_resource.pod_prefix) if new_resource.pod_prefix
    new_resource.requires.each { |u| args.push('--requires', u) }
    new_resource.after.each { |u| args.push('--after', u) }
    new_resource.wants.each { |u| args.push('--wants', u) }
    new_resource.additional_env.each { |e| args.push('--env', e) }
    # `podman generate systemd` takes a single positional and infers whether it
    # is a container or a pod, so `type` is informational only.
    args.push(new_resource.source)
    args
  end

  # Podman separates multiple units with a comment naming the unit file, e.g.
  # `# container-web.service`. A single unit output has no such header, and
  # `no_header` suppresses it, so fall back to the name Podman would use.
  def parse_units(output)
    units = {}
    current = nil
    buffer = []

    flush = lambda do
      units[current] = buffer.join if current
      buffer = []
    end

    output.each_line do |line|
      if (match = line.match(/\A# (\S+\.(?:service|socket))\s*\z/))
        flush.call
        current = match[1]
      elsif current
        buffer << line
      end
    end
    flush.call

    return units unless units.empty?

    { fallback_unit_name => output }
  end

  def fallback_unit_name
    prefix = if new_resource.type == 'pod'
               new_resource.pod_prefix || 'pod'
             else
               new_resource.container_prefix || 'container'
             end
    template_suffix = new_resource.template ? '@' : ''
    "#{prefix}#{new_resource.separator}#{new_resource.source}#{template_suffix}.service"
  end
end
