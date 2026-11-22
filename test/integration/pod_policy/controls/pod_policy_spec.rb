control 'pod-restart-policy' do
  impact 1.0
  title 'The pod carries its restart policy'

  describe command("podman pod inspect --format '{{.RestartPolicy}}' chef-policy-pod") do
    its('stdout') { should match(/on-failure/) }
  end
end
