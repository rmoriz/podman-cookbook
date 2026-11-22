# Podman Cookbook

A Chef cookbook for [Podman](https://podman.io). It mirrors the public resource
surface of the Sous Chefs Docker cookbook (`podman_container`,
`podman_image`, `podman_network`, `podman_volume`, `podman_service`, ...) and
adds Podman-only resources for pods, kube play, secrets, Quadlet units,
generated systemd units and machines.

Podman is daemonless, so every resource drives the `podman` CLI instead of a
daemon API. Rootful and rootless operation, remote `--url`/`--connection`
access and TLS are supported on every resource.

## Scope

* Install Podman from the distribution repositories together with the network
  stack and, where the distribution ships them, the Docker shim and CNI
  plugins.
* Manage containers, images, networks, volumes, pods, secrets and kube
  workloads.
* Generate systemd units, both with Quadlet and `podman generate systemd`.
* Stay on Podman itself: there are no Swarm resources, because Podman has no
  native Swarm mode. Pods (`podman_pod`) and Kubernetes manifests
  (`podman_kube_play`, `podman_kube_generate`) cover the same ground.

## Requirements

* Chef Infra Client 18 or later
* Linux for the engine (remote clients can run anywhere)
* systemd for `podman_service_manager_systemd`

## Platform Support

The current release and its predecessor; older ones are dropped.

* AlmaLinux 9/10
* Amazon Linux 2023
* CentOS Stream 9/10
* Debian 12/13
* Fedora 42/43
* openSUSE Leap 15.6/16.0, Tumbleweed
* Oracle Linux 9/10
* Red Hat Enterprise Linux 9/10
* Rocky Linux 9/10
* Ubuntu 26.04/26.10

Unknown platforms fall back to `podman_installation_script`, which aborts when
it does not know the package manager.

## Installation

```ruby
podman_service 'default' do
  action %i(create start)
end
```

`podman_service` installs packages and starts the socket-backed service. To skip
the service and only install:

```ruby
podman_installation_package 'default' do
  action :create
end
```

Other installers are `podman_installation_script` and
`podman_installation_tarball`; the generic `podman_installation` name resolves
to the script installer, as in the docker cookbook.

## Rootless

Set `run_as 'deploy'` on container-like resources, or use the user units:

```ruby
podman_service 'deploy' do
  user_mode true
  user 'deploy'
  action %i(create start)
end
```

Rootless operation requires `subuid`/`subgid` entries; the package installer
adds `uidmap` (Debian/Ubuntu) or `shadow-utils` (RPM).

## Resources

| Resource | Purpose |
| ---------- | --------- |
| [`podman_container`](documentation/podman_container.md) | Containers |
| [`podman_exec`](documentation/podman_exec.md) | Commands inside a container |
| [`podman_image`](documentation/podman_image.md) | Pull, build, import, push, save, load, remove images |
| [`podman_image_prune`](documentation/podman_image_prune.md) | Remove unused images |
| [`podman_tag`](documentation/podman_tag.md) | Tag images |
| [`podman_network`](documentation/podman_network.md) | Networks, connect/disconnect |
| [`podman_volume`](documentation/podman_volume.md) | Volumes |
| [`podman_volume_prune`](documentation/podman_volume_prune.md) | Remove unused volumes |
| [`podman_registry`](documentation/podman_registry.md) | Registry login |
| [`podman_pod`](documentation/podman_pod.md) | Pods |
| [`podman_kube_play`](documentation/podman_kube_play.md) | Deploy/tear down Kubernetes YAML |
| [`podman_kube_generate`](documentation/podman_kube_generate.md) | Render Kubernetes YAML |
| [`podman_secret`](documentation/podman_secret.md) | Secrets |
| [`podman_quadlet`](documentation/podman_quadlet.md) | Quadlet systemd units |
| [`podman_generate_systemd`](documentation/podman_generate_systemd.md) | `podman generate systemd` units |
| [`podman_machine`](documentation/podman_machine.md) | Podman machines (VM clients) |
| [`podman_service`](documentation/podman_service.md) | Install + API service |
| [`podman_service_base`](documentation/podman_service_base.md) | Shared service-manager settings |
| [`podman_service_manager_systemd`](documentation/podman_service_manager_systemd.md) | systemd socket/service units |
| [`podman_service_manager_execute`](documentation/podman_service_manager_execute.md) | Background `podman system service` |
| [`podman_installation_package`](documentation/podman_installation_package.md) | Package installation |
| [`podman_installation_script`](documentation/podman_installation_script.md) | Script installation |
| [`podman_installation_tarball`](documentation/podman_installation_tarball.md) | Static tarball installation |

Full property documentation lives in [`documentation/`](documentation/).

## Alternative OCI runtimes

Besides `crun`, containers can run under gVisor (`runsc`), a WASM runtime
(`crun-wasm`) or in a microVM (`krun`). `runtime` selects one per container or
pod, `runtimes` on the service registers the binary for Podman — see
[alternative runtimes](documentation/alternative-runtimes.md).

## Remote connections

Every resource accepts `host`, `connection`, `identity_path`, `root`, `runroot`,
`cgroup_manager`, `remote` and the TLS properties, so they can target a remote
Podman service. For `tcp:` hosts the certificate properties become `--tls-ca`,
`--tls-cert` and `--tls-key`:

```ruby
podman_container 'remote-web' do
  host 'tcp://podman.example.com:8443'
  tls_ca_cert '/etc/podman/ca.pem'
  tls_client_cert '/etc/podman/cert.pem'
  tls_client_key '/etc/podman/key.pem'
  repo 'nginx'
  action :run
end
```

## Notes

* Podman's defaults differ from Docker's. The default runtime is `crun`,
  networking uses netavark, and `log_driver` is unset unless specified.
* `restart_policy` and `autoremove` conflict, as in Docker.
* `podman_container` recreates a container when a property changes; it does not
  patch a running container in place.

## Development

```sh
cookstyle
chef exec rspec
```

Integration suites live in `kitchen.yml`, each with InSpec controls under
`test/integration/<suite>`. They need a Linux driver and a real Podman
installation.

## Credits

Thank you to the [sous-chefs/docker](https://github.com/sous-chefs/docker)
cookbook and its authors for the resource surface, documentation layout and
test structure that `podman_*` mirrors.

Without their work this cookbook would not exist.

## License

Apache-2.0
