control 'pulled-image' do
  impact 1.0
  title 'The image was pulled'

  describe command('podman image exists busybox:latest') do
    its('exit_status') { should eq 0 }
  end
end
