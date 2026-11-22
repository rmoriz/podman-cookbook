control 'tagged-image' do
  impact 1.0
  title 'The image was tagged'

  describe command('podman image exists registry.example.com/busybox:chef-test') do
    its('exit_status') { should eq 0 }
  end
end
