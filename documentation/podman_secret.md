# podman_secret

Manages Podman secrets. Podman-only.

## Actions

- `:create`
- `:delete` / `:remove`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `secret_name` | String | resource name | Secret name |
| `value` | String | | Secret value (sensitive) |
| `secret_file` | String | | Read the value from a file |
| `driver` | String | | Secret driver |
| `driver_opts` | Hash | | Driver options |
| `labels` | Hash/Array | `{}` | Labels |
| `replace` | Boolean | `false` | Reconcile an existing secret's labels and driver instead of keeping it |

Without `replace`, an existing secret is left untouched. With `replace`, the
secret is only recreated when its labels or driver differ, because Podman never
exposes the stored value and a metadata-identical secret would otherwise be
rewritten on every run. Changing only `value` therefore needs a new secret name
or an explicit `:delete`. The `--replace` flag is only handed to Podman when the
secret already exists, because Podman below 5 fails a replace with nothing to
replace.

## Example

```ruby
podman_secret 'db-password' do
  value 'correct horse battery staple'
  action :create
end
```
