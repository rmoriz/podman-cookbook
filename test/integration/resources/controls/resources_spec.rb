

control 'podman-container-ran' do
  impact 1.0
  title 'A container was run and removed'

  describe command("podman ps -a --format '{{.Names}}'") do
    its('stdout') { should_not match(/^stopped$/) }
  end
end

control 'podman-pod-removed' do
  impact 0.7
  title 'The test pod was removed'

  describe command("podman pod ps --format '{{.Name}}'") do
    its('stdout') { should_not match(/chef-test-pod/) }
  end
end

control 'podman-secret-removed' do
  impact 0.7
  title 'The test secret was removed'

  describe command("podman secret ls --format '{{.Name}}'") do
    its('stdout') { should_not match(/chef-secret/) }
  end
end

control 'podman-quadlet-unit' do
  impact 0.5
  title 'The quadlet unit was written'

  # `chef-test` is removed again at the end of the recipe, the network unit is
  # not.
  describe file('/etc/containers/systemd/chef-net.network') do
    it { should exist }
    its('content') { should match(%r{^Subnet=10\.89\.0\.0/24$}) }
  end
end

control 'podman-container-runtime' do
  impact 0.5
  title 'The container runs on the requested OCI runtime'

  describe command("podman inspect own-runtime --format '{{.OCIRuntime}}'") do
    its('stdout') { should match(/crun$/) }
  end
end
