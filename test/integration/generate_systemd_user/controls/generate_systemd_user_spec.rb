control 'user-unit' do
  impact 1.0
  title 'The unit was written to the user unit directory'

  describe file('/home/chef/.config/systemd/user/container-web.service') do
    it { should exist }
  end
end
