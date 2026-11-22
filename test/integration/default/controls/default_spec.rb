

control 'podman-binary' do
  impact 1.0
  title 'The podman binary is installed'

  describe command('/usr/bin/podman --version') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/podman version/) }
  end
end

control 'podman-info' do
  impact 1.0
  title 'Podman can report its configuration'

  describe command('/usr/bin/podman info') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/host/) }
  end
end

control 'podman-socket' do
  impact 0.7
  title 'The Podman API socket is enabled'

  describe service('podman.socket') do
    it { should be_enabled }
    it { should be_running }
  end

  describe file('/run/podman/podman.sock') do
    it { should exist }
    it { should be_socket }
  end
end

control 'podman-docker-shim' do
  impact 0.5
  title 'The Docker compatibility shim is installed'

  describe package('podman-docker') do
    it { should be_installed }
  end
end
