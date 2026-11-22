# podman_kube_play

Deploys a Kubernetes YAML manifest with `podman kube play`, no API server
required. Podman-only.

Podman does not expose a comparable state for a played manifest, so `:play`
converges on every run. It passes `--replace` by default, so re-playing an
already deployed manifest works; disable it with `replace false`. Use
`:teardown` (or `down true`) to remove it.

`podman kube play` has no flag for a namespace, labels, extra environment
variables or secrets, so `namespace`, `labels`, `env` and `secrets` are folded
into `manifest_content` before it is played (`metadata.namespace`,
`metadata.labels`, `containers[].env`, `containers[].envFrom[].secretRef` and,
because the play ignores the podman secret store, one `Secret` document per
entry in `secrets` with the data read from that store). A secret's content is
taken as `KEY=VALUE` lines, or as one value under the secret's name. With a
manifest file they have no effect and must already be part of the file.

## Actions

- `:play`
- `:teardown` / `:delete`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `down` | Boolean | `false` | Tear the workload down instead of playing it |
| `manifest` | String | resource name | Path to the manifest |
| `manifest_content` | String | | Inline manifest, sent on stdin (instead of `manifest`) |
| `namespace` | String | | Namespace metadata, applied to `manifest_content` |
| `network` | Array | | Networks |
| `publish` | Array | | Ports |
| `configmaps` | Array | | ConfigMaps |
| `env` | Array | | `KEY=value` pairs, applied to `manifest_content` |
| `secrets` | Array | | Secret names, applied to `manifest_content` as `secretRef` |
| `service_container` | Boolean | `false` | Start Podman's hidden service container first |
| `userns` | String | | User namespace mode |
| `annotation` | Array | `[]` | Podman annotations (`key=value`) |
| `labels` | Hash/Array | `{}` | Labels on the workload, applied to `manifest_content` |
| `build` | Boolean | | Build images on the fly; `false` disables building |
| `context_dir` | String | | Build context for on-the-fly builds |
| `ip` / `mac_address` | String | | Static pod IP / MAC (one per pod) |
| `publish_all` | Boolean | `false` | Publish all `containerPort` entries |
| `no_hosts` | Boolean | `false` | Leave `/etc/hosts` alone |
| `replace` | Boolean | `true` | Replace existing resources (`--replace`) |
| `start` | Boolean | `true` | Start after creating |
| `force` | Boolean | `false` | Force teardown |
| `quiet` | Boolean | `false` | Suppress output |

## Example

```ruby
podman_kube_play '/srv/k8s/app.yaml' do
  action :play
end
```
