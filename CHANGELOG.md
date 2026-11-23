# podman Cookbook CHANGELOG

This file lists changes per release.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.1 (2026-11-23)

### Added

* `annotation` on `podman_container`: OCI annotations as sorted `key=value`
  pairs, validated as KEY=VALUE, compared as a set, and with the annotations
  Podman writes itself filtered out on load so a started container does not
  drift.
* Documentation for the experimental `krun` microVM runtime, covering
  prerequisites, registration, microVM sizing through `memory` and
  `krun.cpus`, passt networking, SELinux volumes and the caveats. The cookbook
  still installs no OCI runtime.

### Changed

* `podman_pod`: a pod `runtime` applies to the infra container only, containers
  joined later need their own `runtime`. Podman has no pod-level
  `--annotation`, so annotations belong on the containers.
* `podman_machine`: note that `provider_type 'libkrun'` is the libkrun machine
  provider and unrelated to the `krun` OCI runtime.

## 0.1.0 (2026-11-22)

Initial release. The cookbook mirrors the public surface of the Sous Chefs
Docker cookbook for Podman and adds the resources Podman has beyond Docker.

Podman is daemonless, so every resource drives the `podman` CLI. The
Docker-compatible Podman API marks `/plugins` unsupported, so there is no
plugin resource.

### Added

* Installation with `podman_installation_package` (distribution packages, the
  default), `podman_installation_script` (bundled installer for unknown
  platforms) and `podman_installation_tarball` (pinned static release with
  checksum verification), each with a matching delete action.
* `podman_service` to combine installation and the service, plus
  `podman_service_base`, `podman_service_manager_systemd` and
  `podman_service_manager_execute` (the former is also provided as
  `podman_service_manager`).
* Container, image, network, volume, exec, tag and registry-login resources
  with the Docker cookbook's properties and actions, including the Docker-only
  spellings as aliases.
* Podman-only resources: `podman_pod`, `podman_kube_play`,
  `podman_kube_generate`, `podman_quadlet`, `podman_secret`,
  `podman_generate_systemd` and `podman_machine`.
* `podman_image_prune` and `podman_volume_prune`.
* Containers without `log_driver` keep the host's default log driver instead of
  being recreated against an assumed `k8s-file`.
* `podman_service_manager_execute` starts a rootless daemon as the socket owner
  instead of root, which served the wrong store, and removes a socket left
  behind by a killed daemon.
* `podman_machine` retries a boot that Podman gave up on, which happens on hosts
  without hardware virtualization.
* `pod` on `podman_container` to join a pod (Podman 6 dropped resolving a pod
  name through `network_mode container:<pod>`).
* Alternative OCI runtimes: `runtime` on `podman_container` and `podman_pod`,
  `runtime`/`runtimes` on the service base to set a default and to register
  runtime binaries, plus documentation for gVisor (`runsc`) and crun-wasm.
* Rootful and rootless operation, remote `--url`/`--connection` access, TLS
  material for the service managers and connection timeouts on every resource.
* Documentation for every resource, ChefSpec unit tests, InSpec integration
  suites for each recipe and a GitHub Actions workflow that runs both.
* Supported platforms, current release and predecessor: AlmaLinux 9/10,
  Amazon Linux 2023, CentOS Stream 9/10, Debian 12/13, Fedora 42/43,
  openSUSE Leap 15.6/16.0 and Tumbleweed, Oracle Linux 9/10, RHEL 9/10,
  Rocky Linux 9/10, Ubuntu 26.04/26.10.

### Notes

* Service settings live in `containers.conf.d` and `registries.conf.d`
  drop-ins. There is no `[storage]` section in `containers.conf`, so storage
  options go through `--root`/`--storage-opt`; there is no `engine.group`
  either, the group only appears in the socket unit.
* `podman kube play` has no flag for a namespace, labels, environment or
  secrets, so those properties are folded into `manifest_content`. With a
  manifest file they must already be part of the file.
* The Docker daemon options `bip`, `fixed_cidr`, `iptables`, `labels` and
  `daemon` are accepted but have no Podman equivalent; see
  `documentation/podman_service_base.md`.
* There are no Swarm resources. Pods and kube manifests cover the same ground.
