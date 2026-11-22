control 'script-removed' do
  impact 1.0
  title 'The installer and packages are gone'

  describe file('/usr/local/sbin/install-podman.sh') do
    it { should_not exist }
  end

  describe command('command -v podman') do
    its('exit_status') { should_not eq 0 }
  end
end
