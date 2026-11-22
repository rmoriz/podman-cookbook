control 'package-install' do
  impact 1.0
  title 'Podman is installed from packages'

  describe command('/usr/bin/podman --version') do
    its('exit_status') { should eq 0 }
  end

  describe package('podman') do
    it { should be_installed }
  end

  describe file('/etc/containers/nodocker') do
    it { should exist }
  end
end
