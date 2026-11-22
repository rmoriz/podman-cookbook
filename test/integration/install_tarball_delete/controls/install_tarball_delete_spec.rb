control 'tarball-removed' do
  impact 1.0
  title 'The tarball binary and link are gone'

  describe file('/usr/local/bin/podman') do
    it { should_not exist }
  end

  describe file('/usr/bin/podman') do
    it { should_not exist }
  end
end
