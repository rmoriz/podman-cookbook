# frozen_string_literal: true

unified_mode true
use '_partial/_base'
use '_partial/_logging'
use '_partial/_service_base'

resource_name :podman_service
provides :podman_service

property :install_method, %w(script package tarball none auto), default: lazy { podman_install_method }, desired_state: false
property :service_manager, %w(execute systemd none auto), default: 'auto', desired_state: false

# podman_installation_script
property :script_url, String, desired_state: false

# podman_installation_tarball
property :checksum, String, desired_state: false
property :source, String, desired_state: false

# podman_installation_package
property :package_version, String, desired_state: false
property :package_name, String, desired_state: false
property :packages, Array, desired_state: false
property :manage_nodocker, [true, false], desired_state: false
property :version, String, desired_state: false
property :package_options, String, desired_state: false

action_class do
  include PodmanCookbook::Helpers::Service

  def validate_install_method
    if new_resource.property_is_set?(:version) && !%w(package tarball).include?(new_resource.install_method)
      raise Chef::Exceptions::ValidationFailed, 'Version property only supported for package and tarball installation methods'
    end
  end

  def property_intersection(source, destination)
    source.class.properties.keys.intersection(destination.class.properties.keys)
  end

  def installation(&block)
    callback = proc {
      copy_properties_from(new_resource, *property_intersection(new_resource, self), exclude: [:install_method])
      instance_exec(&block)
    }

    case new_resource.install_method
    when 'auto', 'package'
      podman_installation_package(new_resource.name, &callback)
    when 'script'
      podman_installation_script(new_resource.name, &callback)
    when 'tarball'
      podman_installation_tarball(new_resource.name, &callback)
    when 'none'
      Chef::Log.info('Skipping Podman installation. Assuming it was handled previously.')
    end
  end

  def svc_manager(&block)
    callback = proc {
      copy_properties_from(new_resource, *property_intersection(new_resource, self),
                           exclude: [:service_manager, :install_method])
      instance_exec(&block)
    }

    case new_resource.service_manager
    when 'auto', 'systemd'
      podman_service_manager_systemd(new_resource.name, &callback)
    when 'execute'
      podman_service_manager_execute(new_resource.name, &callback)
    when 'none'
      Chef::Log.info('Skipping Podman service manager. Assuming it was handled previously.')
    end
  end
end

action :create do
  validate_install_method

  service = new_resource
  installation do
    action :create
    if %w(package auto).include?(service.install_method)
      restart_target service
    elsif %w(script tarball).include?(service.install_method)
      notifies :restart, service, :immediately
    end
  end
end

action :delete do
  installation do
    action :delete
  end
end

action :start do
  svc_manager do
    action :start
  end
end

action :stop do
  svc_manager do
    action :stop
  end
end

action :restart do
  svc_manager do
    action :restart
  end
end
