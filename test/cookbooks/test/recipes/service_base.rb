# frozen_string_literal: true

# Exercises the shared service base through the generic manager alias.
podman_service_manager 'base-instance' do
  log_driver 'journald'
  log_opts ['max-size=10m']
  selinux_enabled false
  labels ['from=chef']
  default_ulimit ['nofile=1024']
  runtime 'crun'
  # Registered so the name resolves without relying on `$PATH`.
  runtimes 'crun' => ['/usr/bin/crun'], 'runsc' => ['/usr/bin/runsc']
  insecure_registry ['registry.example.com']
  registry_mirror ['https://mirror.example.com']
  action :start
end
