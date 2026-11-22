control 'kube-options' do
  impact 1.0
  title 'The manifest was played with the extra options'

  describe command("podman pod ps --format '{{.Name}}'") do
    its('stdout') { should match(/options/) }
  end
end
