control 'env-file' do
  impact 1.0
  title 'The env file entries were folded into the container environment'

  describe command("podman container inspect --format '{{range .Config.Env}}{{println .}}{{end}}' env-file") do
    its('stdout') { should include 'INLINE=1' }
    its('stdout') { should include 'FROM_FILE=yes' }
    its('stdout') { should include 'SECOND=1' }
    its('stdout') { should_not include 'a comment' }
  end
end
