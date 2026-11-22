# frozen_string_literal: true

# user_mode without a user has no home to write the units to.
podman_service_manager_systemd 'rootless' do
  user_mode true
  action :start
end
