# frozen_string_literal: true

# The CI runner has both installation flavours present; remove both so the
# suite can assert that no podman binary is left behind.
podman_installation_script 'default' do
  action :delete
end

podman_installation_tarball 'default' do
  action :delete
end
