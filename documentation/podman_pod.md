# podman_pod

Pods share a network, IPC namespace and ports. Podman-only; there is no Docker
equivalent.

`:create` compares the configured properties with `podman pod inspect` and only
deletes and recreates the pod when something differs. Deleting a pod stops every
container in it, so prefer `replace true` only when you need a forced rebuild.

`runtime` applies to the infra container only; containers joined later need
their own `runtime`. Podman has no pod-level `--annotation`, so annotations go
on the containers ([alternative runtimes](alternative-runtimes.md)).

## Actions

- `:create`
- `:start`
- `:stop`
- `:restart`
- `:pause`
- `:unpause`
- `:kill`
- `:delete` / `:remove`

Add containers with `pod 'name'` on `podman_container`; since Podman 6 the
`network_mode 'container:<pod>'` spelling no longer resolves a pod name.

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `pod_name` | String | resource name | Pod name |
| `labels` | Hash/Array | `{}` | Labels |
| `infra` | Boolean | `true` | Run an infra container (`--infra=false` disables it) |
| `infra_command` | String | | Infra container command |
| `share` | Array | | Namespaces to share |
| `network` | Array | | Networks |
| `network_aliases` | Array | `[]` | Network aliases |
| `publish` | Array | | Published ports |
| `dns` / `dns_search` | Array | | DNS settings |
| `hostname`, `ip`, `mac_address` | String | | Network identity |
| `add_host` | Array | | Extra `/etc/hosts` entries |
| `cgroup_parent` | String | | Cgroup parent |
| `exit_policy` | String | | Infra container exit policy |
| `restart_policy` | String | `'no'` | Restart policy |
| `runtime` | String | | OCI runtime for the infra container, e.g. `runsc` or `crun-wasm` ([details](alternative-runtimes.md)) |
| `signal` | String | `'SIGTERM'` | Signal used by `:kill` |
| `kill_timeout` | Integer | | Seconds before `SIGKILL` |
| `replace` | Boolean | `false` | Replace an existing pod |

## Example

```ruby
podman_pod 'web' do
  publish '8080:80'
  action :create
end

podman_container 'web-nginx' do
  repo 'nginx'
  network_mode 'container:web'
  action :run
end
```
