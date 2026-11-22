# frozen_string_literal: true

require 'spec_helper'

describe 'test::network' do
  platform 'ubuntu', '24.04'
  step_into :podman_network

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_network)
    ).converge(described_recipe)
  end

  before do
    # The recipe continues with :connect, which needs an existing network; the
    # empty label set also makes :create re-run so its flags can be inspected.
    stub_podman(stdout_for: {
                  'network inspect' => JSON.generate(
                    [{
                      'id' => 'net1',
                      'driver' => 'bridge',
                      'labels' => {},
                      'subnets' => [{ 'subnet' => '10.89.0.0/24', 'gateway' => '10.89.0.1' }],
                      'containers' => {},
                    }]
                  ),
                })
    chef_run
  end

  it 'passes user labels and the aux-address drift label to network create' do
    create = podman_commands.find { |command| command.include?('network create') }
    expect(create).to include('--label owner\=chef')
    expect(create).to include('--label aux_address_0\=dns\=10.89.0.53')
    expect(create).to include('--label aux_address_0\=dns\=10.89.0.53')
  end
end
