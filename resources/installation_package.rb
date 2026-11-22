# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_installation_package
provides :podman_installation_package

include PodmanCookbook::Helpers::Install

property :package_name, String, default: 'podman', desired_state: false
property :packages, Array, default: lazy { podman_default_packages }, desired_state: false
property :package_version, String, desired_state: false
property :version, String, desired_state: false
property :package_options, String, desired_state: false
property :manage_nodocker, [true, false], default: true, desired_state: false
property :restart_target, Chef::Resource,
          description: 'Internal: the podman_service resource to notify when the package changes',
          desired_state: false

# The platform family decides the package manager, so it also decides support;
# a Kitchen platform name like `rockylinux-9` differs from the name Ohai
# reports and would not match.
def supported_platform?
  platform_family?('debian', 'rhel', 'fedora', 'suse', 'amazon')
end

action_class do
  include PodmanCookbook::Helpers::Install

  def package_list
    new_resource.package_name == 'podman' ? new_resource.packages : [new_resource.package_name]
  end
end

action :create do
  raise "Podman packages are not supported on #{node['platform_family']}" unless supported_platform?

  version = new_resource.package_version || new_resource.version

  # Amazon Linux keeps Podman in its Supplementary Packages repository.
  package 'spal-release' do
    action :install
  end if platform_family?('amazon')

  package 'podman packages' do
    package_name package_list
    version version if version
    options new_resource.package_options || ('--allow-vendor-change' if platform_family?('suse'))
    action :install
    notifies :restart, new_resource.restart_target, :immediately if new_resource.restart_target
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
    package_name package_list
    action :remove
  end

  return unless new_resource.manage_nodocker

  file '/etc/containers/nodocker' do
    action :delete
  end
end
