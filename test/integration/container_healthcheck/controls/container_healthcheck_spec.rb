control 'healthcheck-container' do
  impact 1.0
  title 'The container exists with a health check'

  describe command("podman inspect --format '{{.Config.Healthcheck.Test}}' health-checked") do
    its('stdout') { should match(/CMD|curl/) }
  end
end
