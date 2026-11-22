# frozen_string_literal: true

require 'spec_helper'

describe 'test::container_network' do
  platform 'ubuntu', '24.04'
  step_into :podman_container

  # A different network mode makes both :create calls run so their flags can
  # be inspected.
  let(:inspect_document) do
    JSON.generate(
      [{
        'Id' => 'abc123',
        'Config' => { 'Image' => 'busybox:latest' },
        'HostConfig' => { 'NetworkMode' => 'host' },
        'State' => { 'Running' => false, 'StartedAt' => '2026-11-22T00:00:00Z' },
      }]
    )
  end

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_container)
    ).converge(described_recipe)
  end

  before { stub_podman(stdout_for: { 'inspect' => inspect_document }) }

  it 'maps the docker default network alias to the bridge' do
    chef_run
    command = podman_commands.find { |entry| entry.include?('--name default-net') }
    expect(command).to include('--network bridge')
  end

  it 'rejects hostnames on a shared container network' do
    expect do
      ChefSpec::SoloRunner.new(
        platform: 'ubuntu',
        version: '24.04',
        step_into: %w(podman_container)
      ).converge('test::container_network_invalid')
    end.to raise_error(Chef::Exceptions::ValidationFailed, /network_mode is container/)
  end

  it 'resolves a container network mode to the container id' do
    chef_run
    command = podman_commands.find { |entry| entry.include?('--name container-net') }
    expect(command).to include('--network container:abc123')
  end

  context 'when the existing containers already match' do
    before do
      stub_podman(
        stdout_for: {
          'json default-net' => JSON.generate(
            [{
              'Id' => 'abc123',
              'Config' => { 'Image' => 'busybox:latest' },
              'HostConfig' => { 'NetworkMode' => 'bridge' },
              'State' => { 'Running' => false, 'StartedAt' => '2026-11-22T00:00:00Z' },
            }]
          ),
          'json container-net' => JSON.generate(
            [{
              'Id' => 'def456',
              'Config' => { 'Image' => 'busybox:latest' },
              'HostConfig' => { 'NetworkMode' => 'container:abc123' },
              'State' => { 'Running' => false, 'StartedAt' => '2026-11-22T00:00:00Z' },
            }]
          ),
          'json hello-world' => JSON.generate([{ 'Id' => 'abc123' }]),
        }
      )
    end

    it 'does not recreate the containers' do
      chef_run
      expect(podman_commands.grep(/container create/)).to be_empty
    end
  end
end
