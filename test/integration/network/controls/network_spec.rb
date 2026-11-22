control 'network-flags' do
  impact 1.0
  title 'The network exists with its driver and label'

  describe command("podman network inspect --format '{{.Driver}}' chef-test") do
    its('stdout') { should match(/bridge/) }
  end

  describe command("podman network inspect --format '{{.Labels.owner}}' chef-test") do
    its('stdout') { should match(/chef/) }
  end
end

control 'network-lifecycle' do
  impact 1.0
  title 'The throwaway network was deleted'

  describe command('podman network exists chef-deleted') do
    its('exit_status') { should_not eq 0 }
  end
end
