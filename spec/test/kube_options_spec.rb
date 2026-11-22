# frozen_string_literal: true

require 'spec_helper'

describe 'test::kube_options' do
  platform 'ubuntu', '24.04'
  step_into :podman_kube_play

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_kube_play)
    ).converge(described_recipe)
  end

  before do
    stub_podman
    chef_run
  end

  it 'passes the annotations and the behaviour flags' do
    command = podman_commands.find { |entry| entry.include?('kube play') }
    expect(command).to include('--annotation io.podman.annotations.userns\=keep-id')
    expect(command).to include('--publish-all')
    expect(command).to include('--no-hosts')
    expect(command).to end_with(' -')
  end

  it 'folds the labels into the manifest instead of a flag' do
    index = podman_commands.index { |entry| entry.include?('kube play') }

    expect(podman_commands[index]).not_to include('--label')
    expect(podman_inputs[index]).to include('app: web')
  end
end
