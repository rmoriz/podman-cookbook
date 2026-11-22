control 'pod-flags' do
  impact 1.0
  title 'The pod exists'

  describe command('podman pod inspect chef-flags-pod') do
    its('exit_status') { should eq 0 }
  end
end

control 'pod-runtime' do
  impact 0.5
  title 'The pod infra container runs on the requested OCI runtime'

  describe command("podman inspect $(podman pod inspect chef-flags-pod --format '{{.InfraContainerID}}') --format '{{.OCIRuntime}}'") do
    its('stdout') { should match(/crun$/) }
  end
end
