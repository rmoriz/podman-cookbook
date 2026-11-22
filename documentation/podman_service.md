# podman_service

Installs Podman and manages the API service. This is the Podman counterpart of
`docker_service`.

`podman_service 'default'` installs packages and enables the Podman socket and
service. Podman is daemonless, but the socket-backed service is what
Docker-compatible clients and remote `--url` connections talk to.

## Actions

- `:create` - Install Podman.
- `:delete` - Remove Podman.
- `:start` - Start the service manager.
- `:stop` - Stop the service manager.
- `:restart` - Restart the service manager.

## Properties

`install_method` (`package`, `script`, `tarball`, `none`, `auto`) and
`service_manager` (`systemd`, `execute`, `none`, `auto`) select the strategy.
All properties of the chosen installation resource and service manager are
accepted, including proxy, DNS, registry mirror, storage, logging and
`user_mode` options.

### Installation pass-through

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `script_url` | String | | Download the installer instead of using the bundled one |
| `source` | String | | Tarball URL |
| `checksum` | String | | Tarball checksum |
| `version` | String | | Package or tarball version |
| `package_version` | String | | Exact package version |
| `package_name` | String | `'podman'` | Package to install |
| `packages` | Array | platform default | Full package list, used by the `package` install method |
| `package_options` | String | | Extra package manager options |
| `manage_nodocker` | Boolean | `true` | Write `/etc/containers/nodocker` |

## Example

```ruby
podman_service 'default' do
  action %i(create start)
end

podman_service 'rootless' do
  user_mode true
  user 'deploy'
  action %i(create start)
end
```
