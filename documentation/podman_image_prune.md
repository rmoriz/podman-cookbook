# podman_image_prune

Removes unused images.

## Actions

- `:prune`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `read_timeout` | Integer | `120` | Seconds before the command times out |
| `dangling` | Boolean | `true` | Only dangling images |
| `prune_until` | String | | Remove images older than a timestamp/duration |
| `with_label` | String | | Only images with this label |
| `without_label` | String | | Only images without this label |

The resource reports a change only when the output shows deleted objects, so an
empty prune stays idempotent.

## Example

```ruby
podman_image_prune 'weekly' do
  dangling true
  prune_until '24h'
  action :prune
end
```
