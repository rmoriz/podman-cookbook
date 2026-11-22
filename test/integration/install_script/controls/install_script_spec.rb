control 'script-install' do
  impact 1.0
  title 'Podman was installed by the bundled script'

  describe file('/usr/local/sbin/install-podman.sh') do
    it { should exist }
    its('mode') { should cmp '0755' }
  end

  describe command('/usr/bin/podman --version') do
    its('exit_status') { should eq 0 }
  end
end
