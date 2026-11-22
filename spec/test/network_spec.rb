# frozen_string_literal: true

require 'spec_helper'

describe 'test::network' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before { stub_podman }

  it 'creates a network with subnet and gateway' do
    expect(chef_run).to create_podman_network('chef-test').with(
      subnet: '10.89.0.0/24',
      gateway: '10.89.0.1',
      driver: 'bridge',
      ipam_driver: 'host-local',
      labels: { 'owner' => 'chef' },
      auxiliary_addresses: ['dns=10.89.0.53']
    )
  end

  it 'runs a container attached to the network' do
    expect(chef_run).to run_podman_container('networked').with(network_mode: 'chef-test')
  end

  it 'connects and disconnects the container' do
    expect(chef_run).to connect_podman_network('chef-test').with(container: 'networked', ip: '10.89.0.20')
    expect(chef_run).to disconnect_podman_network('chef-test').with(container: 'networked')
  end
end

describe 'test::network_lifecycle' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before do
    stub_command('podman network exists chef-deleted').and_return(false)
    stub_podman
  end

  it 'deletes the throwaway network in both spellings' do
    expect(chef_run).to delete_podman_network('chef-deleted')
    expect(chef_run).to remove_podman_network('chef-deleted')
  end
end

describe 'test::network' do
  platform 'ubuntu', '24.04'
  step_into :podman_network

  let(:inspect_document) do
    JSON.generate(
      [{
        'name' => 'chef-test',
        'id' => 'abc123',
        'driver' => 'bridge',
        'network_interface' => 'podman1',
        'created' => '2026-01-01T00:00:00Z',
        'subnets' => [{ 'subnet' => '10.89.0.0/24', 'gateway' => '10.89.0.1' }],
        'ipv6_enabled' => false,
        'internal' => false,
        'dns_enabled' => true,
        'ipam_options' => { 'driver' => 'host-local' },
        'labels' => { 'owner' => 'chef', 'aux_address_0' => 'dns=10.89.0.53' },
      }]
    )
  end

  before { stub_podman(stdout_for: { 'network inspect' => inspect_document }) }

  it 'does not reconnect a container that already carries the address' do
    stub_podman(
      stdout_for: {
        'network inspect' => inspect_document,
        'container inspect' => JSON.generate(
          [{
            'NetworkSettings' => {
              'Networks' => { 'chef-test' => { 'IPAddress' => '10.89.0.20' } },
            },
          }]
        ),
      }
    )
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_network)
    ).converge(described_recipe)

    expect(podman_commands.grep(/network connect/)).to be_empty
  end

  it 'does not recreate an unchanged network' do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_network)
    ).converge(described_recipe)

    expect(podman_commands).not_to include(a_string_matching(/network rm/))
  end
end
