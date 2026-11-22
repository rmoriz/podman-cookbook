# frozen_string_literal: true

require 'spec_helper'

describe 'test::image_build' do
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
    stub_podman
    chef_run
  end

  it 'keeps intermediate images for noprune' do
    build = podman_commands.find { |command| command.include?('build') }
    expect(build).to include('--tag chef-build:latest')
    # `--layers` only controls the cache, `--rm=false` keeps intermediates.
    expect(build).to include('--rm\=false')
    expect(build).not_to include('--layers')
    expect(build).not_to include('--force-rm')
    expect(build).to include('--file /tmp/Dockerfile.build /tmp')
  end
end
