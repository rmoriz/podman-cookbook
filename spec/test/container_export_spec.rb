# frozen_string_literal: true

require 'spec_helper'

describe 'test::container_export' do
  platform 'ubuntu', '24.04'
  step_into :podman_container

  def converge
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_container)
    ).converge(described_recipe)
  end

  let(:outfile) { '/tmp/exports/exporter.tar' }

  before do
    stub_podman
    FileUtils.rm_f(outfile)
  end

  it 'creates the container when it does not exist yet' do
    converge
    expect(podman_commands).to include(a_string_matching(/ create /))
  end

  it 'creates the output directory and exports the container' do
    expect(converge).to create_directory('/tmp/exports').with(recursive: true)
    expect(podman_commands).to include(a_string_matching(%r{export --output /tmp/exports/exporter.tar exporter}))
  end

  it 'leaves an existing archive alone' do
    FileUtils.mkdir_p(File.dirname(outfile))
    FileUtils.touch(outfile)

    converge
    expect(podman_commands).not_to include(a_string_matching(/export --output/))
  end
end
