# podman_service_manager_systemd

Writes and enables `podman.service` and `podman.socket`, or the user units when
`user_mode` is set. `podman_service_manager` is an alias for this resource.

## Actions

- `:start`
- `:stop`
- `:restart`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `instance` | String | resource name | Service instance; `default` uses the plain `podman` unit |
| `group` (`run_group`) | String | `'podman'` | Socket group |
| `env_vars` | Hash | `{}` | Extra daemon environment |
| `http_proxy` | String | | Daemon `HTTP_PROXY` |
| `https_proxy` | String | | Daemon `HTTPS_PROXY` |
| `no_proxy` | String | | Daemon `NO_PROXY` |
| `tmpdir` | String | | `TMPDIR` for the daemon |
| `logfile` | String | `'/var/log/podman.log'` | Log file used by the execute manager |
| `api_cors_header` | String | | `--cors` header |
| `service_timeout` | Integer | `20` | Wait-ready timeout in seconds |
| `systemd_opts` / `systemd_socket_opts` | String/Array | | Extra unit directives |
| `log_driver` / `log_opts` | String/Hash | | Written into `containers.conf` |
| `user_mode`, `user` | Boolean/String | | Rootless units in `~/.config/systemd/user` |
| `systemd_args` | String | derived | Helper rendering `systemd_opts` for a unit file |
| `systemd_socket_args` | String | derived | Helper rendering `systemd_socket_opts` |
| `docker_name` | String | derived | Helper returning the unit name |
| `connect_socket` | String | derived | Helper returning the socket path |
| `docker_daemon_cmd` | String | derived | Helper returning the start command |
| `docker_containerd` | Boolean | `false` | Always false; Podman has no containerd |

Inherits the rest from `podman_service_base`: networking, DNS, storage,
registry, `default_ulimit` and the TLS properties.

Docker-named helpers are available too: `docker_name` (the unit name),
`docker_daemon_cmd` (the start command) and `connect_socket` (the socket path).
`docker_containerd` is always false, as Podman does not use containerd.

The API server certificate comes from `tls_server_cert`/`tls_server_key`; the
Docker cookbook's `tls_client_cert`/`tls_client_key` are used as a fallback for
that pair. `tls_ca_cert` is passed as `--tls-client-ca`. `podman system service`
only learned the TLS flags in Podman 5, so on older builds the unit is written
without them and the socket is served unencrypted.

## Example

```ruby
podman_service_manager_systemd 'default' do
  group 'podman'
  action :start
end

podman_service_manager_systemd 'deploy' do
  user_mode true
  user 'deploy'
  action :start
end
```
