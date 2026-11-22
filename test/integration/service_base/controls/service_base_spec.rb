control 'service-base-config' do
  impact 1.0
  title 'The service base writes the daemon settings into containers.conf'

  describe file('/etc/containers/containers.conf.d/90-podman-podman-base-instance.conf') do
    it { should exist }
    its('content') { should match(/log_driver = "journald"/) }
    its('content') { should match(/^log_size_max = 10485760$/) }
    its('content') { should match(/^label = false$/) }
    its('content') { should_not match(/\[registries\]/) }
    its('content') { should match(/^runtime = "crun"$/) }
    its('content') { should match(/^\[engine\.runtimes\]$/) }
    its('content') { should match(%r{^crun = \["/usr/bin/crun"\]$}) }
    its('content') { should match(%r{^runsc = \["/usr/bin/runsc"\]$}) }
  end
end

control 'service-base-registries' do
  impact 1.0
  title 'The service base writes registry settings into registries.conf.d'

  describe file('/etc/containers/registries.conf.d/90-podman-podman-base-instance.conf') do
    it { should exist }
    its('content') { should match(/location = "registry.example.com"/) }
    its('content') { should match(/location = "mirror.example.com"/) }
  end
end

control 'service-base-unit' do
  impact 1.0
  title 'The manager alias starts a podman service unit'

  describe service('podman-base-instance') do
    it { should be_running }
    it { should be_enabled }
  end
end
