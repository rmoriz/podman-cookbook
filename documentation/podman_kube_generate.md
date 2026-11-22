# podman_kube_generate

Renders a container, pod or volume as Kubernetes YAML with `podman kube
generate`. Podman infers the object type from the name; `type` documents the
intent and rejects typos.

## Actions

- `:generate`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `source` | String | resource name | Container, pod or volume name |
| `type` | String | `'container'` | `container`, `pod` or `volume` |
| `destination` | String | | Output file (an absolute parent directory is created, an existing file is overwritten, the volatile `creationTimestamp` and `nodePort` are left out); sends the YAML to the Chef log when unset |
| `kind` | String | | Kubernetes kind: `pod`, `deployment`, `daemonset` or `job` |
| `replicas` | Integer | | Replica count; only with `kind 'deployment'` |
| `service` | true, false | `false` | Generate a Service object too |
| `podman_only` | true, false | `false` | Add Podman-only annotations |

## Example

```ruby
podman_kube_generate 'web' do
  kind 'deployment'
  replicas 3
  destination '/srv/k8s/web.yaml'
  action :generate
end
```
