control 'built-image' do
  impact 1.0
  title 'The image was built'

  describe command('podman image exists chef-build:latest') do
    its('exit_status') { should eq 0 }
  end
end
