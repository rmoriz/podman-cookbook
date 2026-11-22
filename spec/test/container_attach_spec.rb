# frozen_string_literal: true

require 'spec_helper'

describe 'test::container_attach' do
  platform 'ubuntu', '24.04'
  step_into :podman_container

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_container)
    ).converge(described_recipe)
  end

  before do
    stub_podman
    chef_run
  end

  it 'passes the attach flags to create' do
    create = podman_commands.find { |command| command.include?(' create ') }
    expect(create).to include('--attach stdout')
    expect(create).to include('--attach stderr')
    expect(create).not_to include('--attach stdin')
  end
end
