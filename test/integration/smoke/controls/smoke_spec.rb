control 'smoke-clean' do
  impact 1.0
  title 'The smoke container was removed'

  describe command("podman ps -a --format '{{.Names}}'") do
    its('stdout') { should_not match(/^smoke$/) }
  end
end
