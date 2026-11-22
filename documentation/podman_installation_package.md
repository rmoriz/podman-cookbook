# podman_installation_package

Installs Podman and its supporting packages from the distribution repositories.

## Actions

- `:create` - Install the packages.
- `:delete` - Remove the packages.

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `package_name` | String | `'podman'` | Install only this package instead of the package list |
| `packages` | Array | platform default | Packages to install |
| `package_version` | String | | Pin a package version |
| `version` | String | | Alias for `package_version` |
| `package_options` | String | | Extra package manager options |
| `manage_nodocker` | Boolean | `true` | Write `/etc/containers/nodocker` |
| `restart_target` | Resource | | Service to notify on package changes |

## Package list

`podman`, `netavark` and `aardvark-dns` everywhere, plus the Docker shim
`podman-docker` and `containernetworking-plugins` where the distribution ships
them. Rootless operation adds `uidmap` on Debian/Ubuntu, `shadow` on openSUSE or
`shadow-utils` elsewhere. Amazon Linux first installs `spal-release`, because its
Podman lives in the Supplementary Packages repository; it has no
`containernetworking-plugins`. openSUSE has no CNI plugins either, and EL10 and
later dropped them in favour of netavark.

## Example

```ruby
podman_installation_package 'default' do
  action :create
end

podman_installation_package 'pinned' do
  package_version '5.4.2-1'
  action :create
end
```
