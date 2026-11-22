# frozen_string_literal: true

require 'spec_helper'

describe 'test::prune' do
  platform 'ubuntu', '24.04'
  step_into :podman_image_prune, :podman_volume_prune

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_image_prune podman_volume_prune)
    ).converge(described_recipe)
  end

  before do
    stub_podman(stdout_for: { 'volume prune --help' => "  -a, --all\n" })
  end

  it 'prunes dangling images' do
    chef_run
    expect(chef_run).to prune_podman_image_prune('prune dangling images').with(dangling: true)
    expect(podman_commands).to include(a_string_matching(/image prune --force --filter dangling\\=true/))
  end

  it 'passes every filter as its own flag' do
    chef_run
    command = podman_commands.find { |entry| entry.include?('--filter dangling') && entry.include?('dangling\\=false') }
    expect(command).to include('--filter until')
    expect(command).to include('--filter label\\=chef')
    expect(command).to include('--filter label\\!\\=keep')
  end

  it 'prunes labelled volumes' do
    chef_run
    expect(chef_run).to prune_podman_volume_prune('prune volumes').with(with_label: 'chef=true')
  end

  it 'passes the read timeout to the prune calls' do
    chef_run
    expect(chef_run).to prune_podman_image_prune('prune with a timeout').with(read_timeout: 30)
    expect(chef_run).to prune_podman_volume_prune('prune all volumes').with(all: true, read_timeout: 15)
    expect(podman_commands).to include(a_string_matching(/volume prune --force --all/))
  end

  context 'when the Podman build knows no --all' do
    before { stub_podman(stdout_for: { 'volume prune --help' => '  -f, --force' }) }

    it 'prunes without the flag' do
      chef_run
      expect(podman_commands).to include(a_string_matching(/volume prune --force$/))
      expect(podman_commands.grep(/volume prune --force --all/)).to be_empty
    end
  end
end
