# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_installation_script
provides :podman_installation, os: 'linux'
provides :podman_installation_script

property :script_url, String, desired_state: false
property :installer_path, String, default: '/usr/local/sbin/install-podman.sh', desired_state: false
property :manage_nodocker, [true, false], default: true, desired_state: false

action :create do
  package 'curl'

  if new_resource.script_url
    remote_file new_resource.installer_path do
      source new_resource.script_url
      mode '0755'
    end
  else
    cookbook_file new_resource.installer_path do
      source 'install-podman.sh'
      cookbook 'podman'
      mode '0755'
    end
  end

  execute 'install podman' do
    command new_resource.installer_path
    not_if 'sh -c "command -v podman"'
  end

  if new_resource.manage_nodocker
    directory '/etc/containers' do
      recursive true
    end

    file '/etc/containers/nodocker' do
      content "# Managed by Chef\n"
      owner 'root'
      group 'root'
      mode '0644'
    end
  end
end

action :delete do
  package 'podman packages' do
    package_name podman_default_packages
    action :remove
  end

  file new_resource.installer_path do
    action :delete
  end

  return unless new_resource.manage_nodocker

  file '/etc/containers/nodocker' do
    action :delete
  end
end

action_class do
  include PodmanCookbook::Helpers::Install
end
