# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_installation_tarball
provides :podman_installation_tarball

property :version, String, default: '6.2.0', desired_state: false
property :source, String, default: lazy { default_source }, desired_state: false
property :checksum, String, default: lazy { default_checksum }, desired_state: false
# The archive is rooted with `usr/local` itself, so the extraction root is `/`
# and only the top-level directory is stripped.
property :prefix, String, default: '/', desired_state: false
property :podman_bin, String, default: '/usr/local/bin/podman', desired_state: false
property :manage_nodocker, [true, false], default: true, desired_state: false

def podman_arch
  case node['kernel']['machine']
  when 'x86_64' then 'amd64'
  when 'aarch64' then 'arm64'
  else node['kernel']['machine']
  end
end

def default_source
  "https://github.com/mgoltzsche/podman-static/releases/download/v#{version}/podman-linux-#{podman_arch}.tar.gz"
end

def default_checksum
  case version
  when '6.2.0'
    podman_arch == 'amd64' ? '981bcee9ff6a07b3a3e22b9ea98c9aa10bcf67bac2abdc3049595267122378be' : 'b1bcc37efd6a430dbe5448f07d99544dad435f361bdbab80418a571b5c2d7af1'
  end
end

# The archive is rooted with `podman-linux-<arch>`; only the `usr` tree is
# unpacked and the root directory is stripped.
def tarball_member
  "podman-linux-#{podman_arch}/usr"
end

def tarball
  ::File.join(Chef::Config[:file_cache_path], "podman-#{version}-#{podman_arch}.tar.gz")
end

action :create do
  package 'tar'

  # The extraction runs immediately after the download, so the prefix has to
  # exist before the remote_file resource is declared.
  directory new_resource.prefix do
    recursive true
  end

  if new_resource.checksum.to_s.empty?
    Chef::Log.warn("podman_installation_tarball: no checksum known for #{new_resource.version}, the download is not verified")
  end

  remote_file tarball do
    source new_resource.source
    checksum new_resource.checksum if new_resource.checksum
    owner 'root'
    group 'root'
    mode '0644'
  end

  # Runs after the download by declaration order. The guard keeps a converge
  # from unpacking an up to date binary again, and repairs a missing one.
  # Only `usr` is unpacked: the bundle also carries an /etc/containers config
  # that would overwrite the distribution's one, which the packages own.
  execute 'extract podman tarball' do
    command ['tar', '-xzf', tarball, '--strip-components=1', '-C', new_resource.prefix, tarball_member].shelljoin
    not_if { installed_version == new_resource.version }
  end

  link '/usr/bin/podman' do
    to new_resource.podman_bin
    not_if { new_resource.podman_bin == '/usr/bin/podman' }
  end

  # The bundle carries its own crun next to the podman binary: it writes an OCI
  # spec version the distribution runtimes do not know, so the bundled podman
  # has to run with the bundled crun. A `10-` prefix also lets the service
  # resources override the runtime with their own, later sorting drop-in.
  file '/etc/containers/containers.conf.d/10-podman-tarball-runtime.conf' do
    content "# Managed by Chef - do not edit by hand\n[engine]\nruntime = \"/usr/local/bin/crun\"\n"
    owner 'root'
    group 'root'
    mode '0644'
  end

  group 'podman' do
    system true
    append true
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

action_class do
  # The version of the binary at `podman_bin`, or nil when it is missing or
  # does not answer.
  def installed_version
    result = shell_out([new_resource.podman_bin, '--version'].shelljoin)
    return unless result.exitstatus.zero?

    result.stdout[/\d+\.\d+\.\d+/]
  rescue Errno::ENOENT
    nil
  end
end

action :delete do
  link '/usr/bin/podman' do
    action :delete
  end

  file '/etc/containers/containers.conf.d/10-podman-tarball-runtime.conf' do
    action :delete
  end
  file new_resource.podman_bin do
    action :delete
  end

  return unless new_resource.manage_nodocker

  file '/etc/containers/nodocker' do
    action :delete
  end
end
