# frozen_string_literal: true

podman_image 'busybox' do
  action :pull
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

podman_exec 'failing command' do
  container 'exec-target'
  command ['sh', '-c', 'exit 3']
  returns 3
  action :run
end

podman_exec 'container object' do
  container_obj 'exec-target'
  command %w(true)
  action :run
end
