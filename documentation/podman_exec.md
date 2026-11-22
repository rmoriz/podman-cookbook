# podman_exec

Runs a command inside a running container.

## Actions

- `:run`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `command` | Array | | Command (alias `cmd`) |
| `container` | String | | Target container |
| `container_obj` | String | | Alias target, kept for `docker_exec` parity |
| `timeout` | Numeric | `60` | Command timeout |
| `returns` | Integer/Array | `[0]` | Accepted exit codes |

## Example

```ruby
podman_exec 'migrate' do
  container 'app'
  command %w(/app/bin/migrate)
  action :run
end
```
