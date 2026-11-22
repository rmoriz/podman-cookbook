# frozen_string_literal: true

require 'spec_helper'

describe 'test::install_tarball_delete' do
  platform 'ubuntu', '24.04'
  step_into :podman_installation_tarball

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_installation_tarball)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'removes the unpacked binary and its link' do
    expect(chef_run).to delete_file('/usr/local/bin/podman')
    expect(chef_run).to delete_link('/usr/bin/podman')
  end

  it 'removes the nodocker marker' do
    expect(chef_run).to delete_file('/etc/containers/nodocker')
  end
end
