control 'generated-unit' do
  impact 1.0
  title 'The templated unit was written'

  describe file('/tmp/generated-units/container-templated@.service') do
    it { should exist }
  end
end
