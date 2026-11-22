# frozen_string_literal: true

require 'spec_helper'

describe 'test::pod' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before { stub_podman }

  it 'creates a pod with a published port' do
    expect(chef_run).to create_podman_pod('chef-test-pod').with(publish: ['8080:80'], restart_policy: 'always')
  end

  it 'passes the pod to the container' do
    runner = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_pod podman_container)
    )
    stub_podman(
      stdout_for: {
        'container inspect' => JSON.generate('State' => { 'Running' => true }),
        'pod inspect' => JSON.generate('InfraContainerID' => 'abc', 'State' => 'Running'),
      }
    )
    podman_commands.clear
    runner.converge(described_recipe)
    expect(podman_commands).to include(a_string_matching(/--pod chef-test-pod/))
  end

  it 'runs a container in the pod network' do
    expect(chef_run).to run_podman_container('pod-member').with(pod: 'chef-test-pod')
  end

  it 'starts, pauses, restarts, kills, stops and deletes the pod' do
    expect(chef_run).to start_podman_pod('chef-test-pod')
    expect(chef_run).to pause_podman_pod('chef-test-pod')
    expect(chef_run).to unpause_podman_pod('chef-test-pod')
    expect(chef_run).to restart_podman_pod('chef-test-pod')
    expect(chef_run).to kill_podman_pod('chef-test-pod')
    expect(chef_run).to stop_podman_pod('chef-test-pod')
    expect(chef_run).to delete_podman_pod('chef-test-pod')
  end
end
