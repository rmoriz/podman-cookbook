control 'volume-removed' do
  impact 1.0
  title 'The volume was removed'

  describe command('podman volume inspect chef-test-volume') do
    its('exit_status') { should_not eq 0 }
  end
end
