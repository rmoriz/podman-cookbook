# podman_generate_systemd

Wraps `podman generate systemd`, the pre-Quadlet way to create systemd units.

## Actions

- `:create`

## Behaviour

The generated units are written below `destination`; multiple units are split on
the `# <unit>` headers Podman emits. Any entry in `files` is written as well and
replaces a generated unit with the same name. Newly written units trigger a
`daemon-reload` (`systemctl --user` in user mode).

`template` implies `--new`; Podman refuses `--new=false` for templates, so the
flag is simply left out in that combination.

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `source` | String | resource name | Container or pod |
| `type` | String | `'container'` | `container` or `pod`; informational, Podman infers it from `source` |
| `destination` | String | derived | Unit directory; defaults to the system or user unit dir |
| `user_mode` | Boolean | `false` | Install as a `systemctl --user` unit |
| `user` | String | | Owner of the user unit directory |
| `new_unit` | Boolean | `true` | Emit a unit that creates the container |
| `name_unit` | Boolean | `true` | Name the unit after the container |
| `restart_policy` | String | | `no`, `on-success`, `on-failure`, `on-abnormal`, `on-watchdog`, `on-abort` or `always` |
| `restart_sec` | Integer | | Restart delay |
| `start_timeout` | Integer | | Start timeout |
| `stop_timeout` | Integer | | Stop timeout |
| `no_header` | Boolean | `false` | Omit the Podman version header |
| `template` | Boolean | `false` | Emit a template unit |
| `separator` | String | `'-'` | Name separator |
| `container_prefix`, `pod_prefix` | String | | Name prefixes |
| `requires`, `after`, `wants` | Array | `[]` | Unit ordering |
| `additional_env` | Array | `[]` | Extra environment |
| `files` | Hash | `{}` | Extra units, or overrides keyed by filename |

## Example

```ruby
podman_generate_systemd 'web' do
  restart_policy 'always'
  action :create
end

# Rootless user unit
podman_generate_systemd 'web' do
  user_mode true
  user 'deploy'
  restart_policy 'on-failure'
  action :create
end
```
