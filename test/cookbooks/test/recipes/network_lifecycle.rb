# frozen_string_literal: true

podman_network 'chef-deleted' do
  action :create
end

# Podman refuses to delete a network that a container is attached to, so this
# one stays unattached.
podman_network 'chef-deleted' do
  force true
  action :delete
end

podman_network 'chef-deleted' do
  action :remove
end
