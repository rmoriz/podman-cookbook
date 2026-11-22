# podman_machine

Manages Podman machines (the Linux VMs used on macOS and Windows).

## Actions

- `:init`
- `:start`
- `:stop`
- `:remove`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `machine_name` | String | resource name | Machine name |
| `cpus` | Integer | | vCPUs |
| `memory` | Integer | | Memory in MiB |
| `disk_size` | Integer | | Disk size in GiB |
| `image` | String | | Boot image |
| `provider_type` | String | | Provider |
| `rootful` | Boolean | `false` | Rootful machine |
| `user_mode_networking` | Boolean | `false` | User-mode networking |
| `volume` | Array | `[]` | Mounts |
| `timezone` | String | | Timezone |
| `playbook` | String | | Provisioning playbook |
| `now` | Boolean | `true` | Boot the machine right after `:init` |
| `run_as` | String | | User to run as; `podman machine` refuses to run as root |
| `read_timeout` | Integer | `900` | Seconds to wait for boot and shutdown |
| `start_attempts` | Integer | `10` | Boot attempts before giving up |

`podman machine` only works for a non-root user, so set `run_as` (and make sure
that user owns its home directory). Put that home below `/home` or `/mnt`:
Podman mounts the home into the VM, and for any other target Podman 4 first runs
`chattr -i /` in the guest, which fails on the overlay root of a Fedora CoreOS
image and aborts the boot.

Podman gives up on a boot that does not answer SSH in time and then leaves the
VM running but unreachable. Without hardware virtualization a boot easily
outlasts that wait, so the resource stops the machine and boots it again, up to
`start_attempts` times. Each further boot starts from the already provisioned
disk and is faster, but the budget only helps while a boot occasionally fits
into the wait: Podman terminates the port forwarder when it gives up, so a boot
that always takes longer cannot be reached afterwards. A restart also terminates the VM's port forwarder and waits
until both processes are gone: a forwarder that is still shutting down keeps the
forwarded SSH port, and the next boot could not bind it.

The boot is started separately instead of through `machine init --now`, because
the ignition file Podman 4 writes needs a fix-up first:

- `/etc/subuid` and `/etc/subgid` are written without a trailing newline, and
  the Podman in a current Fedora CoreOS image rejects such a file with
  `Non-text file`, so the boot fails although the VM is up. The resource
  encodes the missing newline in the ignition.
- `ready.service`, whose output `machine start` waits for, requires
  `/dev/virtio-ports/vport1p1`. Kernels since 6.x name that port after its tag
  instead, so the unit never starts and `machine start` waits forever. The
  resource retargets the unit at `/dev/vport1p1`.

Both fixes stay valid for later boots, and `:start` applies them again, so a
machine that another run initialised is repaired as well. When the ignition
cannot be reached, the retry path additionally appends the subuid newline in the
guest over SSH.

The identity file is also set to mode `0600` before every boot: `ssh` refuses a
world-readable private key, and an install can leave one behind under a
permissive umask, which fails the boot wait with `Permission denied (publickey)`
even though the guest is fine.

The VM runs under qemu and needs hardware virtualization (`/dev/kvm` on the
host) plus `qemu-system-*`, `gvproxy` and `virtiofsd`. The cookbook installs
none of them. Podman looks for `gvproxy` and `virtiofsd` in its helper
directory, and distributions ship `virtiofsd` as `/usr/libexec/virtiofsd`, so
link it next to the other helpers:

```sh
ln -s /usr/libexec/virtiofsd /usr/libexec/podman/virtiofsd
```

`provider_type 'libkrun'` selects the libkrun machine provider (macOS, needs
`krunkit`). It is unrelated to the `krun` OCI runtime.

## Example

```ruby
user 'machine' do
  manage_home true
end

podman_machine 'podman-machine-default' do
  run_as 'machine'
  cpus 4
  memory 4096
  action :init
end
```
