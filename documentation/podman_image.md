# podman_image

Manages images with the `podman` CLI.

## Actions

- `:pull` - Pull the image; the resource only reports a change when the digest moved.
- `:build` - Build an image from `source`.
- `:build_if_missing` - Build only when `repo:tag` is absent.
- `:pull_if_missing` - Pull only when `repo:tag` is absent.
- `:import` - Import a tarball as `repo:tag`.
- `:push` - Push `repo:tag`.
- `:remove` - Remove the image.
- `:save` - Save the image to `destination`; an absolute parent directory is created.
- `:load` - Load the image from `source`.

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `read_timeout` | Integer | `120` | Seconds before the pull or push times out |
| `repo` | String | resource name | Repository (alias `image`, `image_name`) |
| `tag` | String | `'latest'` | Tag or `sha256:` digest |
| `source` | String | | Build context directory, Dockerfile or tar for `:build`/`:import`/`:load`. A plain file is passed as `--file` with its directory as the context. |
| `destination` | String | | Output path for `:save` |
| `buildargs` | Hash/String | | Build arguments |
| `nocache` | Boolean | `false` | Disable the build cache |
| `noprune` | Boolean | `false` | Keep intermediate images (`--rm=false`; not `--layers`, which only controls the cache) |
| `rm` | Boolean | `true` | Remove intermediate containers |
| `force` | Boolean | `false` | Force removal |

## Examples

```ruby
podman_image 'alpine' do
  action :pull
end

podman_image 'myapp' do
  tag 'v1'
  source '/srv/myapp'
  action :build
end
```
