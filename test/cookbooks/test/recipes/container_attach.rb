# frozen_string_literal: true

podman_container 'attached' do
  repo 'busybox'
  command 'echo attached'
  detach false
  attach_stdout true
  attach_stderr true
  action :create
end
