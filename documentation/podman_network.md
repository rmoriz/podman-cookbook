# podman_network

Manages Podman networks (netavark).

## Actions

- `:create`
- `:delete` / `:remove` (an unattached network; `force` also drops the attached containers)
- `:connect`
- `:disconnect`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `id` | String | | Existing network, from `docker_network` |
| `ipam_driver` | String | | IPAM driver |
| `network_name` | String | resource name | Network name |
| `driver` | String | | Network driver |
| `driver_opts` | Hash | | Driver options |
| `subnet` | String/Array | | Subnet(s) |
| `gateway` | String/Array | | Gateway(s) |
| `ip_range` | String/Array | | Allocation range(s) |
| `auxiliary_addresses` | String/Array | | `name=ip` pairs (alias `aux_address`), kept as labels |
| `internal` | Boolean | | Internal-only network |
| `enable_ipv6` | Boolean | | Enable IPv6 |
| `dns_disabled` | Boolean | `false` | Disable DNS |
| `container` | String | | Container for `:connect`/`:disconnect` |
| `ip` / `ip6` | String | | Address to assign on connect |
| `labels` | String/Array/Hash | | Network labels (`--label`) |
| `force` | Boolean | `false` | Delete even while containers are attached |

## Example

`podman network create` has no `--aux-address` flag, so auxiliary addresses are
only stored as numbered `aux_address_<n>` labels. Podman's inspect output does
not report them either, and the numbering keeps several addresses
distinguishable for drift detection.

```ruby
podman_network 'backend' do
  subnet '10.89.1.0/24'
  labels 'owner' => 'chef'
  auxiliary_addresses 'dns' => '10.89.1.53'
  action :create
end

podman_network 'backend' do
  container 'api'
  ip '10.89.1.10'
  action :connect
end
```
