# podman_volume

Manages Podman volumes.

## Actions

- `:create`
- `:remove`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `volume_name` | String | resource name | Volume name |
| `driver` | String | | Volume driver |
| `opts` | Hash | | Driver options |

`:create` compares `driver` and `opts` with `podman volume inspect`. Podman
cannot change either in place, so a differing volume is removed and recreated.
Data in the volume is lost; the volume also cannot be recreated while a
container still uses it.

## Example

```ruby
podman_volume 'data' do
  driver 'local'
  opts('type' => 'none', 'o' => 'bind', 'device' => '/srv/data')
  action :create
end
```
