# frozen_string_literal: true

# `podman system service` reads the files at startup and refuses to run
# without them, so the recipes have to create real material.
directory '/etc/podman'

execute 'create the test TLS CA' do
  command 'openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=chef-test-ca -keyout /etc/podman/ca.key -out /etc/podman/ca.crt'
  not_if 'test -s /etc/podman/ca.crt'
end

execute 'create the test TLS client certificate' do
  command <<~CMD
    openssl req -newkey rsa:2048 -nodes -subj /CN=chef-test-client -keyout /etc/podman/client.key -out /tmp/client.csr &&
    openssl x509 -req -days 1 -in /tmp/client.csr -CA /etc/podman/ca.crt -CAkey /etc/podman/ca.key -CAcreateserial -out /etc/podman/client.crt
  CMD
  not_if 'test -s /etc/podman/client.crt'
end
