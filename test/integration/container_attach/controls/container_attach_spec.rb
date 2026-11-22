control 'attach-config' do
  impact 1.0
  title 'Attaching to the container prints its output'

  describe command('podman start --attach attached') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/attached/) }
  end
end
