control 'kube-cli-generate' do
  impact 1.0
  title 'The manifest was written by the podman kube generate wrapper'

  describe file('/tmp/web.yaml') do
    its('content') { should match(/kind: Deployment/) }
    its('content') { should match(/replicas: 2/) }
    its('content') { should match(/kind: Service/) }
  end
end
