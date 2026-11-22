# podman_service_base

Shared base resource for the service managers (`podman_service_manager_execute`
and `podman_service_manager_systemd`). `podman_service_manager` resolves to the
systemd manager. Numbers for a plain `podman_service` run are copied from this
resource.

Podman has no daemon configuration file. Settings with a `containers.conf`
equivalent go into a drop-in (`<conf dir>/90-podman-<name>.conf`), storage is
passed to the service as global flags and registry settings go into a
`registries.conf.d` drop-in. The daemon runs as `podman system service`.

## Actions

The base declares no actions. Use it only when a resource needs the shared
properties without starting anything; the managers define `:start`, `:stop` and
`:restart`.

## Properties

`instance` (resource name), `env_vars`, `auto_restart`, `daemon`, networking and
DNS settings, `labels`, `log_driver`/`log_opts`, `group` (`run_group`), the
storage and registry settings, proxy variables, `logfile`, `service_timeout`,
`default_ulimit`, `pidfile`, the TLS pair and the systemd options. Rootless
operation uses `user_mode` and `user`.

`runtime` names the default OCI runtime and `runtimes` registers search paths
per runtime name; both are described in
[alternative runtimes](alternative-runtimes.md).

`data_root`/`root`, `runroot`, `storage_driver` and `storage_opts` are passed as
global flags. `registry_mirror` and `insecure_registry` are written as a
`registries.conf.d` drop-in; a leading `https://` is stripped because Podman
wants a bare host. `cgroup_manager`, `runtime`, `env_vars`, `dns`,
`dns_search`, `default_ulimit`, `bridge`, `userns_remap`, `log_driver`,
`selinux_enabled` (as containers.conf's `label`), the
`max-size` value of `log_opts` (converted to bytes for `log_size_max`), the
proxies, `tmpdir`, `bip`/`fixed_cidr`, `default_ip_address_pool`,
`iptables`/`ip6tables` and `service_timeout` go into `containers.conf`.

The Docker daemon options without a Podman counterpart are accepted so recipes
keep parsing, but have no effect: `cluster_store`, `cluster_advertise`,
`cluster_store_opts`, `exec_driver`, `exec_opts`, `daemon`, `labels`, `ip_forward`, `ip_masq`,
`icc`, `mtu`, `mount_flags`, `misc_opts`, `userland_proxy`,
`disable_legacy_registry`, `live_restore`, `fixed_cidr_v6` and `auto_restart`.

## Example

```ruby
podman_service_base 'default' do
  log_driver 'journald'
  userland_proxy false
  action :start
end
```
