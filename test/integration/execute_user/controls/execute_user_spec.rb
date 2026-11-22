control 'execute-user-service' do
  impact 0.7
  title 'The execute manager answers on the rootless socket'

  describe command("podman --url=unix:///run/user/$(id -u podman)/podman/podman.sock info --format '{{.Host.Arch}}'") do
    its('exit_status') { should eq 0 }
  end
end
