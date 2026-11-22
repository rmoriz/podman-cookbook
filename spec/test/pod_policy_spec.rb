# frozen_string_literal: true

require 'spec_helper'

describe 'test::pod_policy' do
  platform 'ubuntu', '24.04'
  step_into :podman_pod

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_pod)
    ).converge(described_recipe)
  end

  before do
    # The pod exists with a different restart policy.
    stub_podman(
      stdout_for: {
        'pod inspect' => JSON.generate([{ 'Name' => 'chef-policy-pod', 'RestartPolicy' => 'no', 'Labels' => {} }]),
      }
    )
    chef_run
  end

  it 'recreates the pod when the restart policy drifts' do
    expect(podman_commands.any? { |command| command.include?('pod rm --force chef-policy-pod') }).to be(true)
    create = podman_commands.find { |command| command.include?('pod create') }
    expect(create).to include('--restart on-failure')
  end
end
