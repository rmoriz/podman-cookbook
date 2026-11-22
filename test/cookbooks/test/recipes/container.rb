# frozen_string_literal: true

podman_image 'busybox' do
  action :pull
end

podman_container 'hello-world' do
  repo 'busybox'
  command '/bin/echo hello'
  action :create
end

podman_container 'alpine_ls' do
  repo 'alpine'
  command 'ls -la /'
  action :run_if_missing
end

podman_container 'busybox_ls' do
  repo 'busybox'
  command 'ls -la /'
  action :run
end

podman_container 'labeled' do
  repo 'busybox'
  command 'sleep 300'
  labels('chef' => 'test', 'role' => 'worker')
  env ['FOO=bar']
  restart_policy 'unless-stopped'
  action :run
end

podman_container 'stopped' do
  repo 'busybox'
  command 'sleep 300'
  action :run
end

podman_container 'stopped' do
  action :stop
end

podman_container 'stopped' do
  action :delete
end

podman_container 'exec-target' do
  repo 'busybox'
  command 'sleep 300'
  action :run
end

podman_exec 'write file' do
  container 'exec-target'
  command ['sh', '-c', 'echo hi > /tmp/hi']
  action :run
end

podman_container 'exec-target' do
  action :delete
end

podman_container 'lifecycle' do
  repo 'busybox'
  command 'sleep 300'
  action :run
end

podman_container 'lifecycle' do
  action :pause
end

podman_container 'lifecycle' do
  action :unpause
end

podman_container 'lifecycle' do
  action :restart
end

podman_container 'lifecycle' do
  action :reload
end

podman_container 'lifecycle' do
  repo 'busybox'
  command 'sleep 300'
  action :redeploy
end

podman_container 'lifecycle' do
  action :kill
end

podman_container 'lifecycle' do
  action :commit
end

podman_container 'lifecycle' do
  action :export
  outfile '/tmp/lifecycle.tar'
end

podman_container 'lifecycle' do
  action :delete
  force true
  remove_volumes true
end

# Alternative OCI runtimes are chosen per container; `crun` is always present.
podman_container 'own-runtime' do
  repo 'busybox'
  command 'sleep 300'
  runtime 'crun'
  annotation %w(krun.ram_mib=2048 krun.cpus=2)
  action :run
end

podman_container 'published' do
  repo 'busybox'
  port_bindings '8080:80'
  exposed_ports '443/tcp'
  action :create
end
