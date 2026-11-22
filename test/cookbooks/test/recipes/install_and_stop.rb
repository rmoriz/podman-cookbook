# frozen_string_literal: true

# The installation suites leave the lock file of another Podman build behind and
# the runtime refuses a file of the other build's size.
file '/dev/shm/libpod_lock' do
  action :delete
end

podman_service 'default' do
  action %i(create start stop)
end
