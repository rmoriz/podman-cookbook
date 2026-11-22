# frozen_string_literal: true

require 'spec_helper'

describe 'test::image' do
  platform 'ubuntu', '24.04'
  step_into :podman_image

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_image)
    ).converge(described_recipe)
  end

  before do
    # `save` writes to `<destination>.tmp` and renames it; the stub does not
    # create that file.
    allow(FileUtils).to receive(:mv)
    stub_podman
    chef_run
  end

  it 'creates the destination directory before saving' do
    expect(chef_run).to create_directory('/tmp').with(recursive: true)
  end
end
