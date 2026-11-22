# podman_installation_script

Runs the bundled `install-podman.sh` (or a custom script) to install Podman. The
script picks the package manager of the running distribution and installs the
same package set as `podman_installation_package`.

## Actions

- `:create`
- `:delete`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `script_url` | String | | Download a script instead of using the bundled one |
| `installer_path` | String | `/usr/local/sbin/install-podman.sh` | Where the script is stored |
| `manage_nodocker` | Boolean | `true` | Write `/etc/containers/nodocker` |

## Example

```ruby
podman_installation_script 'default' do
  action :create
end
```
