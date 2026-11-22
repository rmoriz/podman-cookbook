# frozen_string_literal: true

podman_image 'busybox' do
  action :pull
end

# The container has to stay up; exec does not work on an exited one.
podman_container 'smoke' do
  repo 'busybox'
  command %w(sleep 300)
  action :run
end

podman_exec 'smoke echo' do
  container 'smoke'
  command %w(echo ok)
  action :run
end

podman_container 'smoke' do
  action :delete
end
