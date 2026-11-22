control 'kube-source-torn-down' do
  impact 1.0
  title 'The played manifest was torn down again'

  describe file('/tmp/kube-source.yaml') do
    it { should exist }
  end

  describe command('podman pod exists kube-source-pod') do
    its('exit_status') { should_not eq 0 }
  end
end

control 'kube-inline-workload' do
  impact 1.0
  title 'The inline manifest was played with its namespace and secret'

  describe command('podman pod exists inline') do
    its('exit_status') { should eq 0 }
  end

  describe command('podman secret exists inline-secret') do
    its('exit_status') { should eq 0 }
  end

  describe command("podman pod inspect --format '{{.Name}}' inline") do
    its('stdout') { should eq "inline\n" }
  end
end
