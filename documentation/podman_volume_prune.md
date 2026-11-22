# podman_volume_prune

Removes unused volumes.

## Actions

- `:prune`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `read_timeout` | Integer | `120` | Seconds before the command times out |
| `all` | Boolean | `false` | Also remove named volumes, not just anonymous ones |
| `with_label` | String | | Only volumes with this label |
| `without_label` | String | | Only volumes without this label |
| `host` | String | | Remote endpoint (`DOCKER_HOST`-style) |

The resource reports a change only when the output shows deleted objects, so an
empty prune stays idempotent. Podman below 5 has no `--all` and there prunes
only anonymous volumes either way.

## Example

```ruby
podman_volume_prune 'cleanup' do
  action :prune
end
```
