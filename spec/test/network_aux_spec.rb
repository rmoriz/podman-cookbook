# frozen_string_literal: true

require 'spec_helper'

describe 'test::network_aux' do
  platform 'ubuntu', '24.04'
  step_into :podman_network

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_network)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'records every auxiliary address in a numbered drift label' do
    chef_run
    create = podman_commands.find { |command| command.include?('network create') }
    # Podman has no --aux-address flag, and shelljoin escapes the `=`.
    expect(create).not_to include('--aux-address')
    expect(create).to include('--label aux_address_0\=router\=10.90.0.2')
    expect(create).to include('--label aux_address_1\=printer\=10.90.0.3')
  end

  context 'when the recorded addresses come back from inspect' do
    before do
      stub_podman(
        stdout_for: {
          'network inspect' => JSON.generate(
            [{
              'id' => 'aux1',
              'driver' => 'bridge',
              'labels' => {
                'aux_address_0' => 'router=10.90.0.2',
                'aux_address_1' => 'printer=10.90.0.3',
              },
              'subnets' => [{ 'subnet' => '10.90.0.0/24', 'gateway' => '10.90.0.1' }],
              'containers' => {},
            }]
          ),
        }
      )
    end

    it 'does not recreate the network' do
      chef_run
      expect(podman_commands.grep(/network create/)).to be_empty
    end
  end
end
