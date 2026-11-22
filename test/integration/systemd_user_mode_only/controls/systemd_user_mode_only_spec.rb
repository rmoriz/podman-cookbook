control 'rootless-service' do
  impact 1.0
  title 'The rootless service unit exists'

  describe file('/home/chef/.config/systemd/user/podman-rootless.service') do
    it { should exist }
  end
end
