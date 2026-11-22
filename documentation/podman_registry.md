# podman_registry

Logs in to a container registry with `podman login`.

An unchanged login is skipped when `podman login --get-login` already reports
the configured username for the host.

## Actions

- `:login`

## Properties

| Property | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `serveraddress` | String | resource name | Registry host |
| `username` | String | | Username |
| `password` | String | | Password (sensitive, sent on stdin) |
| `email` | String | | Email, stored in the run state |
| `tls_verify` | Boolean | `true` | Verify the registry certificate |

## Example

```ruby
podman_registry 'registry.example.com' do
  username 'deploy'
  password 'secret'
  action :login
end
```

A plain-HTTP registry needs `tls_verify false`:

```ruby
podman_registry '127.0.0.1:5000' do
  tls_verify false
  username 'deploy'
  password 'secret'
  action :login
end
```
