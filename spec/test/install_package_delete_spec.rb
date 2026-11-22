# frozen_string_literal: true

require 'spec_helper'

describe 'test::install_package_delete' do
  platform 'opensuse', '15.2'
  step_into :podman_installation_package

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'opensuse',
      version: '15.2',
      step_into: %w(podman_installation_package)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'removes the package list' do
    expect(chef_run).to remove_package('podman packages')
  end

  it 'removes the nodocker marker' do
    expect(chef_run).to delete_file('/etc/containers/nodocker')
  end
end
