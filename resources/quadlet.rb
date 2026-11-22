# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_quadlet
provides :podman_quadlet

# Quadlet turns `.container`, `.pod`, `.network`, `.volume` and `.kube` files
# under /etc/containers/systemd into systemd units at boot.
property :unit_name, String, name_property: true
property :type, %w(container pod network volume kube), default: 'container'
property :content, String
property :directory, String, default: '/etc/containers/systemd'
property :user_mode, [true, false], default: false
property :user, String
property :mode, String, default: '0644'
property :service_name, String
property :require_units, [String, Array], default: [], coerce: proc { |v| Array(v) }
property :after_units, [String, Array], default: [], coerce: proc { |v| Array(v) }
property :install_wanted_by, String, default: 'default.target'
property :instance_name, String

action :create do
  raise Chef::Exceptions::ValidationFailed, 'podman_quadlet needs unit content' if new_resource.content.nil?

  directory target_directory do
    owner new_resource.user || 'root' if new_resource.user_mode
    group new_resource.user || 'root' if new_resource.user_mode
    recursive true
  end

  file unit_path do
    content unit_content
    owner new_resource.user || 'root' if new_resource.user_mode
    group new_resource.user || 'root' if new_resource.user_mode
    mode new_resource.mode
    notifies :run, "execute[quadlet daemon-reload #{unit_path}]", :immediately
  end

  execute "quadlet daemon-reload #{unit_path}" do
    command daemon_reload_command
    environment systemd_environment
    action :nothing
  end
end

action :delete do
  file unit_path do
    action :delete
    notifies :run, "execute[quadlet daemon-reload #{unit_path}]", :immediately
  end

  execute "quadlet daemon-reload #{unit_path}" do
    command daemon_reload_command
    environment systemd_environment
    action :nothing
  end
end

action :start do
  execute "start #{effective_service}" do
    command [*systemctl, 'start', effective_service].shelljoin
    environment systemd_environment
    user new_resource.user if new_resource.user_mode && new_resource.user
    not_if { unit_active? }
  end
end

action :stop do
  execute "stop #{effective_service}" do
    command [*systemctl, 'stop', effective_service].shelljoin
    environment systemd_environment
    user new_resource.user if new_resource.user_mode && new_resource.user
    only_if { unit_active? }
  end
end

action :enable do
  execute "enable #{effective_service}" do
    # Quadlet units are generated and already linked into
    # `default.target.wants`, so `systemctl enable` refuses them as transient.
    # Only a unit with a real enablement symlink takes `enable`; everything else
    # systemd reports (`generated`, `static`, `alias`, ...) is only started.
    command lazy {
      state = enableable_states.include?(unit_state) ? ['enable', '--now'] : ['start']
      [*systemctl, *state, effective_service].shelljoin
    }
    environment systemd_environment
    user new_resource.user if new_resource.user_mode && new_resource.user
    not_if { unit_enabled? && unit_active? }
  end
end

action_class do
  def target_directory
    return new_resource.directory unless new_resource.user_mode

    ::File.join(user_home, '.config/containers/systemd')
  end

  def user_home
    return '/root' unless new_resource.user
    ::Etc.getpwnam(new_resource.user).dir
  rescue ArgumentError
    Chef::Log.warn("podman: run_as user #{new_resource.user} does not exist")
    "/home/#{new_resource.user}"
  end

  # Insert the unit dependencies and install section around the supplied
  # Quadlet content, leaving an existing section in place.
  def unit_content
    content = new_resource.content
    return content if content.nil?

    content = set_container_name(content) if new_resource.type == 'container'
    unit_lines = Array(new_resource.require_units).map { |unit| "Requires=#{unit}" }
    unit_lines += Array(new_resource.after_units).map { |unit| "After=#{unit}" }
    unless unit_lines.empty?
      content = if content.match?(/^\[Unit\]$/)
                  content.sub(/^\[Unit\]\n/) { |match| match + unit_lines.join("\n") + "\n" }
                else
                  "[Unit]\n#{unit_lines.join("\n")}\n\n#{content}"
                end
    end
    if new_resource.install_wanted_by && !content.match?(/^\[Install\]$/)
      content += "\n[Install]\nWantedBy=#{new_resource.install_wanted_by}\n"
    end
    content
  end

  def unit_path
    suffix = new_resource.type
    filename = new_resource.instance_name ? "#{new_resource.unit_name}@.#{suffix}" : "#{new_resource.unit_name}.#{suffix}"
    ::File.join(target_directory, filename)
  end

  # Quadlet derives the container name from the unit and keeps the `@` of an
  # instanced unit, which Podman below 5 rejects as a container name. Setting
  # `ContainerName=` explicitly keeps the unit startable on every version: the
  # `@` becomes `-`, and an instance template keeps `%i`, which Podman expands
  # per instance so that two instances do not collide. An existing setting wins.
  def set_container_name(content)
    return content if content.match?(/^ContainerName=/)

    line = "ContainerName=#{container_name}\n"
    if content.match?(/^\[Container\]$/)
      content.sub(/^\[Container\]\n/) { |match| match + line }
    else
      "[Container]\n#{line}\n#{content}"
    end
  end

  def container_name
    name = new_resource.instance_name ? "#{new_resource.unit_name}-%i" : new_resource.unit_name
    "systemd-#{name.gsub(/[^A-Za-z0-9_.%-]/, '-')}"
  end

  def effective_service
    return new_resource.service_name if new_resource.service_name

    suffix = { 'network' => '-network', 'volume' => '-volume', 'pod' => '-pod' }.fetch(new_resource.type, '')
    service = "#{new_resource.unit_name}#{suffix}"
    service = "#{service}@#{new_resource.instance_name}" if new_resource.instance_name
    "#{service}.service"
  end

  def systemctl
    new_resource.user_mode ? %w(systemctl --user) : %w(systemctl)
  end

  def daemon_reload_command
    [*systemctl, 'daemon-reload'].shelljoin
  end

  def systemd_environment
    return {} unless new_resource.user_mode && new_resource.user
    uid = ::Etc.getpwnam(new_resource.user).uid
    {
      'XDG_RUNTIME_DIR' => "/run/user/#{uid}",
      'DBUS_SESSION_BUS_ADDRESS' => "unix:path=/run/user/#{uid}/bus",
    }
  end

  # The guards have to run as the same user as the executes, otherwise they
  # report the root unit state for a user unit.
  def unit_state_options
    options = { environment: systemd_environment }
    options[:user] = new_resource.user if new_resource.user_mode && new_resource.user
    options
  end

  def unit_active?
    shell_out([*systemctl, 'is-active', effective_service].shelljoin, **unit_state_options).exitstatus.zero?
  end

  def unit_enabled?
    shell_out([*systemctl, 'is-enabled', effective_service].shelljoin, **unit_state_options).exitstatus.zero?
  end

  def unit_state
    shell_out([*systemctl, 'is-enabled', effective_service].shelljoin, **unit_state_options).stdout.to_s.strip
  end

  # An empty answer means systemd does not know the unit; `enable` is the
  # better bet there, because `start` would refuse it as well.
  def enableable_states
    ['', 'enabled', 'disabled', 'enabled-runtime']
  end
end
