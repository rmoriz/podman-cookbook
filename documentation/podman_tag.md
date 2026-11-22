# podman_tag

Tags an image under a second name.

## Actions

- `:tag`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `target_repo` | String | resource name | Source repository |
| `target_tag` | String | `'latest'` | Source tag |
| `to_repo` | String | | Destination repository |
| `to_tag` | String | `'latest'` | Destination tag |
| `force` | Boolean | `false` | Retag even when the destination exists |

## Example

```ruby
podman_tag 'myapp' do
  target_tag 'latest'
  to_repo 'registry.example.com/myapp'
  to_tag 'v1'
  action :tag
end
```
