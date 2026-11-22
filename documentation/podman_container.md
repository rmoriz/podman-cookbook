# podman_container

Manages Podman containers through the `podman` CLI. It is the Podman counterpart
of `docker_container` and keeps its actions and property names, while using
Podman defaults (`crun`, netavark).

Containers are process oriented and move through an event cycle.

## Actions

- `:create` - Creates the container but does not start it.
- `:start` - Starts the container.
- `:run` - Creates and starts the container. Recreates it when a property changes.
- `:run_if_missing` - Runs a container only once.
- `:stop` - Stops the container.
- `:restart` - Restarts the container.
- `:kill` - Sends `signal` to the container process.
- `:pause` - Pauses the container.
- `:unpause` - Unpauses the container.
- `:delete` - Deletes the container and any container joined to it with `network_mode container:`.
- `:remove` - Alias for `:delete`, from `docker_container`.
- `:reload` - Sends `reload_signal` (default `SIGHUP`) to PID 1.
- `:redeploy` - Deletes and runs the container.
- `:commit` - Commits the container to `repo:tag`.
- `:export` - Exports the container filesystem to `outfile`; an absolute parent directory is created.

## Properties

Most properties mirror `docker_container` and the `podman run` flags.

### Core

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `container_name` | String | resource name | Container name |
| `repo` | String | `container_name` | Image repository |
| `annotation` | Array | `[]` | OCI annotations (`key=value`), e.g. `krun.cpus=2` |
| `tag` | String | `'latest'` | Image tag or `sha256:` digest |
| `command` | Array/String | | Command to run |
| `entrypoint` | Array/String | | Entrypoint override |
| `user` | String | | User or UID |
| `working_dir` | String | | Working directory |
| `hostname` | String | | Container hostname |
| `domain_name` | String | | DNS domain, folded into `--hostname` (Podman has no `--domainname`) |
| `labels` | Hash/Array | `{}` | Labels |
| `env` | Array | `[]` | Environment variables |
| `env_file` | Array | `[]` | Environment files, read and passed as `--env` |
| `tty` | Boolean | `false` | Allocate a TTY |
| `open_stdin` | Boolean | `false` | Keep stdin open |
| `autoremove` | Boolean | `false` | Remove on exit (`--rm`) |
| `privileged` | Boolean | `false` | Privileged mode |
| `init` | Boolean | | Run an init process |
| `attach_stdout` / `attach_stderr` | Boolean | `false` | Stream output on run (`--attach`) |
| `attach_stdin` / `stdin_once` | Boolean | `false` | Attach stdin for the run |
| `detach` | Boolean | `true` | Detach after the run |
| `force` | Boolean | `false` | Force removal, and rewrite an existing `outfile` on `:export` |
| `remove_volumes` | Boolean | `false` | Remove anonymous volumes with the container |
| `runtime` | String | | OCI runtime for this container, e.g. `runsc` or `crun-wasm` ([details](alternative-runtimes.md)) |
| `pod` | String | | Join this pod, e.g. `pod 'web'` |
| `timeout` | Integer | | Seconds to wait for stop |
| `kill_after` | Integer | | Seconds between `SIGTERM` and `SIGKILL` |
| `read_timeout` / `write_timeout` | Integer | `120` | Shell timeouts for reads and for commands that get stdin |
| `container` | Hash | | Mirrors `docker_container`'s `container` hash |
| `create_options` | Hash | `{}` | Extra options for create only |
| `volumes_binds` | Array | | Resolved bind list, maintained internally |
| `links` | Array | | Legacy container links, recorded as labels; Podman resolves by name |
| `gpu_driver` | String | `'nvidia'` | Driver used for `gpus` |

### Networking

`network_mode`, `network_disabled`, `network_aliases`, `exposed_ports`,
`port_bindings`, `publish_all_ports`, `dns`, `dns_search`, `extra_hosts`,
`ip_address`, `mac_address`.

`network_mode` defaults to `bridge`. The Docker cookbook's `default` alias is
accepted and mapped to `bridge`. Podman accepts `container:<name>` directly, so
no ID lookup is needed for Podman itself, but the resource resolves the name to
the container ID to keep the value stable across restarts.

Sharing another container's namespace means the namespace owner provides the
identity, so `hostname`, `dns`, `dns_search`, extra hosts, ports and MAC address
are rejected with a `container:` network mode, just like the Docker cookbook
does.

### Storage

`volumes` (alias `binds`, `volume`), `volumes_from`, `volume_driver`, `tmpfs`,
`working_dir`.

### Resources

`cpus`, `cpu_shares`, `cpuset_cpus`, `memory`, `memory_swap`,
`memory_swappiness`, `memory_reservation`, `shm_size`, `ulimits`,
`oom_kill_disable`, `oom_score_adj`, `pids_limit`.

### Security

`cap_add`, `cap_drop`, `security_opt`, `devices`, `sysctls`, `ro_rootfs`,
`userns_mode`, `ipc_mode`, `pid_mode`, `uts_mode`, `cgroup_parent`, `cgroup_ns`,
`gpus`.

### Restart, health and logging

`restart_policy` (`no`, `always`, `unless-stopped`, `on-failure`),
`restart_maximum_retry_count`, `health_check`, `log_driver`, `log_opts`.

`log_driver` only accepts what Podman supports: `k8s-file`, `journald`, `none`,
`passthrough`, `passthrough-tty` and the `json-file` alias. Leaving `log_driver`
unset keeps the host default from `containers.conf`. Both log properties are
compared against `HostConfig.LogConfig` of an existing container, so a changed
setting recreates the container instead of being ignored.

### Connection

`host`, `connection`, `identity_path`, `root`, `runroot`, `cgroup_manager`,
`remote`, `run_as`, `podman_bin`, `api_retries` and the read/write timeouts.
The service resources add `data_root`/`storage_driver`/`storage_opts`, which
become `--root` and `--storage-opt` flags.

For `tcp:` hosts, `tls_ca_cert`, `tls_client_cert` and `tls_client_key` are
passed as `--tls-ca`, `--tls-cert` and `--tls-key`. `tls`, `tls_verify` and
`cert_dir` are accepted from Docker recipes, but Podman has no matching global
flag, so they only feed their environment defaults.

## Examples

```ruby
podman_image 'nginx' do
  action :pull
end

podman_container 'web' do
  repo 'nginx'
  port_bindings '8080:80'
  volumes '/srv/www:/usr/share/nginx/html:ro,Z'
  restart_policy 'unless-stopped'
  action :run
end

podman_container 'job' do
  repo 'busybox'
  command %w(sh -c 'echo done')
  action :run
end
```
