# frozen_string_literal: true

require 'spec_helper'

describe 'test::volume' do
  platform 'ubuntu', '24.04'
  step_into :podman_volume

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_volume)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'creates a volume with driver options' do
    chef_run
    create = podman_commands.find { |command| command.include?('volume create') }
    expect(create).to include('--driver local')
    expect(create).to include('--opt type\=none')
    expect(create).to include('--opt device\=/srv')
  end

  it 'prunes labelled volumes' do
    expect(chef_run).to prune_podman_volume_prune('prune').with(with_label: 'chef=true')
  end

  context 'when the volume already matches' do
    before do
      stub_podman(
        stdout_for: {
          'volume inspect' => JSON.generate(
            [{
              'Name' => 'chef-test-volume',
              'Driver' => 'local',
              'Options' => { 'type' => 'none', 'o' => 'bind', 'device' => '/srv' },
            }]
          ),
        }
      )
    end

    it 'does not create it again' do
      chef_run
      expect(podman_commands.grep(/volume create/)).to be_empty
      # The recipe still runs its `:remove` resource afterwards.
      expect(podman_commands.grep(/volume rm/).size).to eq(1)
    end
  end

  context 'when the volume has a different driver' do
    before do
      stub_podman(
        stdout_for: {
          'volume inspect' => JSON.generate(
            [{ 'Name' => 'chef-test-volume', 'Driver' => 'other', 'Options' => {} }]
          ),
        }
      )
    end

    it 'recreates it' do
      chef_run
      expect(podman_commands.grep(/volume rm chef-test-volume/)).not_to be_empty
      expect(podman_commands.grep(/volume create/)).not_to be_empty
    end
  end
end
