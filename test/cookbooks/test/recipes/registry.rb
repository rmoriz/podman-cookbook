# frozen_string_literal: true

# A throwaway local registry, so the login does not need the internet.
podman_container 'test-registry' do
  repo 'docker.io/library/registry'
  tag '2'
  port_bindings '5000:5000'
  action :run
end

# `docker-entrypoint` takes a moment before it answers. The guard makes the
# wait idempotent, so a second converge does not touch the resource.
execute 'wait for the test registry' do
  command 'podman exec test-registry wget -qO- http://127.0.0.1:5000/v2/'
  not_if 'sh -c "podman exec test-registry wget -qO- http://127.0.0.1:5000/v2/ 2>/dev/null"'
  retries 15
  retry_delay 1
end

podman_registry '127.0.0.1:5000' do
  # The throwaway registry speaks plain HTTP.
  tls_verify false
  username 'chef'
  password 'secret'
  email 'chef@example.com'
  action :login
end
