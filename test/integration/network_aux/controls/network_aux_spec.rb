control 'network-aux-address' do
  impact 1.0
  title 'The auxiliary address reached the network configuration'

  describe command("podman network inspect --format '{{.Labels}} {{.Subnets}}' chef-aux") do
    its('stdout') { should match(/10\.90\.0\.2/) }
  end
end
