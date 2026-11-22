control 'package-delete' do
  impact 1.0
  title 'The package installer removes Podman and the nodocker marker'

  describe package('podman') do
    it { should_not be_installed }
  end

  describe file('/etc/containers/nodocker') do
    it { should_not exist }
  end
end
