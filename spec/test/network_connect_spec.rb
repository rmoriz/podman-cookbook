# frozen_string_literal: true

require 'spec_helper'

describe 'test::network_connect' do
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
    stub_podman(
      stdout_for: {
        'network inspect' => JSON.generate([{ 'name' => 'chef-connect' }]),
        'container inspect' => JSON.generate(
          [{
            'NetworkSettings' => {
              'Networks' => {
                'chef-connect' => { 'IPAddress' => '10.89.0.21', 'GlobalIPv6Address' => 'fd00::21' },
              },
            },
          }]
        ),
      }
    )
    chef_run
  end

  it 're-attaches the container when either address changed' do
    expect(podman_commands.any? { |command| command.include?('network disconnect chef-connect networked') }).to be(true)
    connect = podman_commands.find { |command| command.include?('network connect') }
    expect(connect).to include('--ip 10.89.0.20')
    expect(connect).to include('--ip6 fd00::20')
  end
end
