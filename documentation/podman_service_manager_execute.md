# podman_service_manager_execute

Runs `podman system service` as a background process and writes a pidfile,
without systemd.

## Actions

- `:start`
- `:stop`
- `:restart`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `pidfile` | String | `/run/podman-<name>.pid` | Pid file used for the guard and stop |
| `logfile` | String | `'/var/log/podman.log'` | Where the daemon output goes |
| `http_proxy` | String | | Daemon `HTTP_PROXY` |
| `https_proxy` | String | | Daemon `HTTPS_PROXY` |
| `no_proxy` | String | | Daemon `NO_PROXY` |
| `tmpdir` | String | | `TMPDIR` for the daemon |
| `docker_daemon_cmd` | String | | Helper returning the server command |

The other settings come from `podman_service_base`. `podman_daemon_cmd` (alias
`docker_daemon_cmd`) returns the `podman system service` command, and
`connect_socket` the socket path.

TLS follows the systemd manager: `tls_server_cert`/`tls_server_key`, with the
client pair as a fallback, and `tls_ca_cert` for the client CA. `podman system
service` only learned the TLS flags in Podman 5, so on older builds the daemon is
started without them and serves the socket unencrypted.

## Rootless

With `user_mode true` the daemon has to run as the socket owner, otherwise it
serves root's store behind a socket that belongs to the user. The manager keeps
the shell itself as root, because the log and pid files live in root-owned
directories, and starts the daemon with `su` as `user`. `su` keeps the
environment of the caller, so `HOME` and the `XDG_*` paths are handed over
explicitly: Podman refuses a home directory that belongs to someone else, and it
prefers `XDG_CONFIG_HOME` over `HOME`, which matters when the caller runs with
another user's environment. That user needs a home directory it owns.

Rootless Podman selects the systemd cgroup manager and therefore needs the
user's runtime directory and user manager. Both only exist while the user is
logged in, so enable lingering (`loginctl enable-linger <user>`) when the daemon
is started outside a session, as this manager does.

The manager creates that runtime directory itself when it is missing, owned by
the user with mode `0700` like logind does, and waits for the user manager
before starting the daemon. That ordering matters: logind wipes and re-creates
the runtime directory while it sets up the manager, and it can do that after
the manager socket already appeared, taking the socket directory with it. The
socket directory is therefore created by the start command, after the manager
answered, and the start is repeated with a fresh directory until the daemon
answers, so a late wipe does not leave an unreachable socket behind.

A manager that was killed leaves its socket behind. The manager removes the
socket before it starts a new daemon unless the old one still answers.

## Example

```ruby
podman_service_manager_execute 'default' do
  action :start
end
```
