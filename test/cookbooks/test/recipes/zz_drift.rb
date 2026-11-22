# frozen_string_literal: true

podman_container 'drift-check' do
  repo 'busybox'
  command 'sleep 300'
  hostname 'app'
  domain_name 'example.com'
  links ['db:database']
  annotation %w(krun.ram_mib=2048 krun.cpus=2)
  volumes 'appdata:/data'
  volume_driver 'local'
  action :create
end
