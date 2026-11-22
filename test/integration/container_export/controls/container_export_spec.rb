control 'exported-filesystem' do
  impact 1.0
  title 'The container filesystem was exported'

  describe file('/tmp/exports/exporter.tar') do
    it { should exist }
    its('size') { should be > 0 }
  end
end
