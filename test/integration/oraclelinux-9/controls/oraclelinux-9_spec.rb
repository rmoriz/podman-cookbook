control 'podman-installed' do
  impact 1.0
  title 'Podman is installed and runs'

  describe command('/usr/bin/podman --version') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/podman version/) }
  end
end

control 'podman-package' do
  impact 1.0
  title 'Podman comes from the distribution packages'

  describe package('podman') do
    it { should be_installed }
  end
end
