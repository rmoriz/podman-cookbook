# frozen_string_literal: true

# `podman machine` refuses to run as root, so the suites use their own user.
user 'podmanmachine' do
  home '/home/podmanmachine'
  shell '/bin/bash'
  manage_home true
end

# The runner's /dev/kvm is not open for everyone, and the machine runs qemu as
# the unprivileged user, so make the device usable for it.
execute 'make /dev/kvm accessible' do
  command 'chmod 0666 /dev/kvm'
  only_if { ::File.exist?('/dev/kvm') && (::File.stat('/dev/kvm').mode & 0o777) != 0o666 }
end

execute 'enable lingering for podmanmachine' do
  command %w(loginctl enable-linger podmanmachine)
  not_if 'sh -c "loginctl show-user podmanmachine --property=Linger | grep -q Linger=yes"'
end

# Podman machine boots a qemu VM; the runners do not ship qemu.
if node['kernel']['machine'] == 'aarch64'
  package 'qemu-system-arm'
else
  package 'qemu-system-x86'
end
# Podman shares the machine home into the VM; Podman 5 and later do that
# through virtiofsd, Podman 4 through the kernel's 9p.
package 'virtiofsd'

# A machine that does not exist yet, so init has to run first here as well.
# A small disk keeps the guest from growing its filesystem at boot, which is
# very slow without hardware virtualization.
podman_machine 'ci' do
  run_as 'podmanmachine'
  cpus 2
  memory 2048
  disk_size 20
  read_timeout 1800
  action :init
end

podman_machine 'ci' do
  run_as 'podmanmachine'
  read_timeout 1800
  action :start
end

podman_machine 'ci' do
  run_as 'podmanmachine'
  read_timeout 1800
  action :stop
end

podman_machine 'ci' do
  run_as 'podmanmachine'
  action :remove
end
