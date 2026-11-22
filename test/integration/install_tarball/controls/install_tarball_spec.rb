control 'tarball-install' do
  impact 1.0
  title 'Podman was unpacked from the static tarball'

  describe file('/usr/local/bin/podman') do
    it { should exist }
    it { should be_executable }
  end
end
