control 'quadlet-file' do
  impact 1.0
  title 'The Quadlet unit file exists'

  describe file('/etc/containers/systemd/chef-empty.container') do
    it { should exist }
  end
end
