# podman_quadlet

Writes Quadlet unit files, the modern way to run containers under systemd.

## Actions

- `:create`
- `:delete`
- `:start`
- `:stop`
- `:enable`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `unit_name` | String | resource name | Unit base name |
| `type` | String | `'container'` | `container`, `pod`, `network`, `volume` or `kube` |
| `content` | String | | Unit file content |
| `directory` | String | `'/etc/containers/systemd'` | System unit directory |
| `user_mode` | Boolean | `false` | Write user units |
| `user` | String | | User for rootless units |
| `mode` | String | `'0644'` | File mode |
| `service_name` | String | derived | Generated service name |
| `instance_name` | String | | Template instance; the generated service is `name@instance.service` (or `name-pod@instance.service` for other types) |
| `install_wanted_by` | String | `'default.target'` | Install target |
| `require_units` | Array | `[]` | `[Unit] Requires=` dependencies |
| `after_units` | Array | `[]` | `[Unit] After=` ordering |

For `container` units the resource writes a `ContainerName=systemd-<unit>` line
into the `[Container]` section unless the content already sets one. Quadlet
otherwise derives the name from the unit and keeps the `@` of an instanced unit,
which Podman below 5 rejects as a container name; the resource writes the `@` as
`-` instead. An `instance_name` becomes `%i` in the name, which Podman expands
per started instance, so several instances of one template unit stay distinct.

## Example

```ruby
podman_quadlet 'web' do
  content <<~UNIT
    [Container]
    Image=docker.io/library/nginx:latest
    PublishPort=8080:80

    [Install]
    WantedBy=default.target
  UNIT
  action :create
end
```
