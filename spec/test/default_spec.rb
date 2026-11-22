# frozen_string_literal: true

require 'spec_helper'

describe 'test::default' do
  platform 'ubuntu', '24.04'
  step_into :podman_service, :podman_installation_package, :podman_service_manager_systemd

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_service podman_installation_package podman_service_manager_systemd)
    ).converge(described_recipe)
  end

  before do
    stub_podman
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv4.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv6.conf.all.forwarding | grep ^1$"').and_return(true)
  end

  it 'installs the podman packages' do
    expect(chef_run).to install_package('podman packages').with(
      package_name: %w(podman netavark aardvark-dns podman-docker containernetworking-plugins uidmap)
    )
  end

  it 'starts the podman service' do
    expect(chef_run).to start_podman_service('default')
  end
end
