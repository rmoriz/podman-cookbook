control 'default-network-created' do
  impact 1.0
  title 'The container using the default network alias is created'

  describe command('podman container exists default-net') do
    its('exit_status') { should eq 0 }
  end
end

control 'container-network-mode' do
  impact 1.0
  title 'The container shares the namespace of its reference container'

  describe command("podman container inspect --format '{{.HostConfig.NetworkMode}}' container-net") do
    its('stdout') { should match(/^container:/) }
  end
end
