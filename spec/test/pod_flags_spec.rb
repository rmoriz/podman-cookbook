# frozen_string_literal: true

require 'spec_helper'

describe 'test::pod_flags' do
  platform 'ubuntu', '24.04'
  step_into :podman_pod

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_pod)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'passes the runtime to the infra container' do
    chef_run
    create = podman_commands.find { |command| command.include?('pod create') }
    expect(create).to include('--runtime crun')
  end

  it 'passes the name once and joins the shared namespaces' do
    chef_run
    create = podman_commands.find { |command| command.include?('pod create') }
    expect(create).to include('pod create --name chef-flags-pod --share ipc,net')
    expect(create.scan('chef-flags-pod').size).to eq(1)
  end

  context 'when the existing pod already matches' do
    before do
      stub_podman(
        stdout_for: {
          'pod inspect' => JSON.generate(
            [{
              'Id' => 'abc123',
              'Name' => 'chef-flags-pod',
              'CreateInfra' => true,
              'SharedNamespaces' => %w(net ipc),
              'RestartPolicy' => 'no',
            }]
          ),
        }
      )
    end

    it 'does not recreate the pod' do
      chef_run
      expect(podman_commands.grep(/pod create/)).to be_empty
    end
  end
end
