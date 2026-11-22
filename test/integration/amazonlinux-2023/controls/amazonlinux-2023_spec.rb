control 'podman-installed' do
  impact 1.0
  title 'Podman is installed and runs from the distribution packages'

  describe command('/usr/bin/podman --version') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/podman version/) }
  end
end
