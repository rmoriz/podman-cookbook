control 'rootless-service' do
  impact 1.0
  title 'The rootless service unit exists'

  describe file('/home/podman/.config/systemd/user/podman-rootless.service') do
    it { should exist }
  end
end

control 'rootless-socket' do
  impact 1.0
  title 'The rootless socket unit is enabled for the user'

  # The enablement symlink is checked rather than `is-enabled`, because that
  # needs the session bus the verifier may not reach.
  describe file('/home/podman/.config/systemd/user/sockets.target.wants/podman-rootless.socket') do
    it { should be_symlink }
  end

  describe file('/home/podman/.config/systemd/user/podman-rootless.socket') do
    it { should exist }
  end
end
