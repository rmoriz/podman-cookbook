control 'registry-login' do
  impact 1.0
  title 'Credentials were stored for the registry'

  describe command('podman login --get-login 127.0.0.1:5000') do
    its('stdout') { should match(/chef/) }
  end
end
