# podman_installation_tarball

Installs the static Podman build from `mgoltzsche/podman-static`. Useful on
distributions without packages or for tests.

## Actions

- `:create`
- `:delete`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `version` | String | `'6.2.0'` | Release version |
| `source` | String | derived | Tarball URL |
| `checksum` | String | known for `6.2.0` | Tarball checksum; empty for other versions, which installs unverified |
| `prefix` | String | `/` | Extraction root; the archive is rooted with `usr/local`, only its top directory is stripped and only `usr` is unpacked |
| `podman_bin` | String | `/usr/local/bin/podman` | Expected binary |
| `manage_nodocker` | Boolean | `true` | Write `/etc/containers/nodocker` |

## Example

```ruby
podman_installation_tarball 'default' do
  action :create
end
```
