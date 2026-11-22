# frozen_string_literal: true

# Quadlet units have no meaning without content.
podman_quadlet 'chef-empty' do
  action :create
end
