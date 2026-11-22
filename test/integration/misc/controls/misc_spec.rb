control 'misc-artifacts' do
  impact 1.0
  title 'The script installer and generated unit exist'

  describe file('/usr/local/sbin/install-podman.sh') do
    it { should exist }
  end

  describe file('/etc/systemd/system/container-web.service') do
    it { should exist }
  end

  describe file('/etc/systemd/system/extra.service') do
    it { should exist }
    its('content') { should match(/Description=extra/) }
  end
end
