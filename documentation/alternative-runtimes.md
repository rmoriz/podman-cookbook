# Alternative OCI runtimes

Podman runs containers through an OCI runtime and ships `crun` as its default.
Other runtimes give containers a stronger or different isolation, and Podman
supports them without the cookbook having to know about each one:

| Runtime | Name | Isolation | Installed with |
| --------- | ------ | ----------- | ---------------- |
| crun (default) | `crun` | namespaces + seccomp | Podman package |
| runc | `runc` | namespaces + seccomp | `runc` package |
| gVisor | `runsc` | user-space kernel | static `runsc` binary from [gVisor releases](https://github.com/google/gvisor/releases) |
| crun-wasm | `crun-wasm` | WASM sandbox, no Linux syscalls | `crun` built with WASM support (`crun-wasm` binary) |
| krun | `krun` | lightweight microVM (libkrun) | Fedora `crun-krun`, Arch `krun`, otherwise built from source |

The cookbook installs none of them: the tarball installer only ships `crun`, and
the package names differ far too much between distributions to guess. Install
the runtime with the distribution package manager or the upstream release, then
register it.

## Registering a runtime

Podman resolves a runtime name through the `[engine.runtimes]` map, falling back
to `$PATH`. Registering the path is the reliable way, because Podman rejects
names it cannot resolve:

```ruby
podman_service 'default' do
  runtimes 'runsc' => ['/usr/bin/runsc'],
           'crun-wasm' => ['/usr/libexec/crun-wasm']
  action %i(create start)
end
```

That writes the following into the `containers.conf` drop-in of the service:

```toml
[engine.runtimes]
runsc = ["/usr/bin/runsc"]
crun-wasm = ["/usr/libexec/crun-wasm"]
```

`podman info --format '{{.Host.OCIRuntime.Name}}'` shows the runtime in effect;
`podman info` lists every registered one.

## Choosing a runtime

`runtime` on `podman_service_base` makes a runtime the default for every
container the service starts:

```ruby
podman_service 'default' do
  runtime 'runsc'
  runtimes 'runsc' => ['/usr/bin/runsc']
  action %i(create start)
end
```

`podman_container` and `podman_pod` select it per workload, which is what most
recipes want — a distro package that misbehaves under gVisor keeps running on
`crun`:

```ruby
podman_container 'untrusted' do
  repo 'docker.io/library/alpine'
  command 'sleep 300'
  runtime 'runsc'
  action :run
end

podman_pod 'wasm-pod' do
  runtime 'crun-wasm'
  action :create
end
```

On a pod the runtime applies to the infra container only: containers joined
later keep their own `runtime` or the engine default, so set it on each of them
to isolate the whole pod. Podman has no pod-level `--annotation`, so the infra
container cannot be sized and annotations belong on the workload containers. A
krun infra container runs `/pause` and is fine with the defaults.

## MicroVM isolation with krun

`krun` is `crun` with the libkrun handler: every container runs in its own
lightweight microVM with its own guest kernel. Of the runtimes here it is the
one meant for genuinely untrusted workloads, and it is experimental.

It needs hardware virtualization that the unprivileged user may open
(`/dev/kvm`), `/etc/subuid` and `/etc/subgid` entries, and a host with `passt`
for the passt mode. Fedora packages it as `crun-krun`, Arch as `krun`; Debian,
Ubuntu and Rocky need `libkrun` and `crun` built from source with a `krun`
symlink to `crun` on `$PATH`.

```ruby
podman_service 'default' do
  runtimes 'krun' => ['/usr/bin/krun']
  action %i(create start)
end

podman_container 'sandbox' do
  repo 'docker.io/library/alpine'
  command %w(sleep 300)
  runtime 'krun'
  memory 2048
  annotation %w(krun.cpus=2)
  action :run
end
```

`memory` sets the OCI limit that the handler derives `krun.ram_mib` from, 1024
MiB without one; `krun.ram_mib` overrides it and values below 128 MiB are
ignored. `krun.cpus` defaults to the CPU affinity set, at most 16. Annotations
without the runtime work too and fit quadlets and OCI bundles:
`run.oci.handler=krun` switches any `crun` invocation to krun, and
`podman_quadlet` takes the same `Annotation=krun.cpus=2` line in its `content`.
Further annotations: `krun.use_passt=1` (passt networking), `krun.tap_name`,
`krun.nested_virt=1`, `krun.gpu_flags` (needs `/dev/dri`), `krun.custom_kernel`,
`krun.variant`. A `.krun_vm.json` in the image root gives the same defaults from
inside.

The default network mode is TSI, which proxies sockets in the VMM: a guest can
publish TCP ports but cannot listen on UDP, and it has no DNS of its own.
`krun.use_passt=1` switches to passt and fixes both; forwarding below port 1024
then needs `net.ipv4.ip_unprivileged_port_start` at or below the target port.

## Caveats

- gVisor implements a subset of the syscalls; `ptrace`, some `ioctl` families
  and nested container workloads often need `crun` instead.
- `crun-wasm` only runs WASM images and needs `--platform wasi/wasm`. Podman
  derives it from the image manifest for pods and containers created through the
  API, but a Linux image under `crun-wasm` fails to start.
- A runtime registered but not installed makes `podman info` warn and the
  container fail at start, not at create time.
- `krun` boots as root and ignores the image `USER`; switch users in the
  entrypoint. Use `:Z` or `:z` on volumes so SELinux lets the guest read them.
- `krun` needs `/dev/kvm`; without hardware virtualization it cannot run.
- The microVM boundary is not a full VM: host devices and the VMM itself stay
  reachable. Prefer a real VM for hostile code.
- Neither CI nor the local suites have `/dev/kvm`, so krun is documented and
  unit-tested only.
