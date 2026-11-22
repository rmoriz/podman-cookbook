control 'podman-stopped' do
  impact 1.0
  title 'The podman service was installed and stopped'

  describe command('/usr/bin/podman --version') do
    its('exit_status') { should eq 0 }
  end

  describe service('podman') do
    it { should_not be_running }
  end
end
