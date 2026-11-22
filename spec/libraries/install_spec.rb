# frozen_string_literal: true

require 'spec_helper'
require_relative '../../libraries/helpers_install'

describe PodmanCookbook::Helpers::Install do
  let(:harness) do
    Class.new do
      include PodmanCookbook::Helpers::Install
      attr_accessor :node
    end.new
  end

  def node_for(platform_family, platform = 'debian')
    { 'platform' => platform, 'platform_family' => platform_family }
  end

  it 'installs the docker shim and CNI plugins on Debian' do
    harness.node = node_for('debian')
    expect(harness.podman_default_packages).to eq(
      %w(podman netavark aardvark-dns podman-docker containernetworking-plugins uidmap)
    )
  end

  it 'uses shadow and skips the CNI plugins on openSUSE' do
    harness.node = node_for('suse', 'opensuseleap')
    expect(harness.podman_default_packages).to include('shadow')
    expect(harness.podman_default_packages).not_to include('shadow-utils', 'containernetworking-plugins')
  end

  it 'uses shadow-utils on RPM platforms' do
    harness.node = node_for('rhel', 'rocky')
    expect(harness.podman_default_packages).to include('shadow-utils', 'podman-docker')
  end

  it 'skips the CNI plugins on EL10' do
    harness.node = node_for('rhel', 'almalinux').merge('platform_version' => '10.0')
    expect(harness.podman_default_packages).not_to include('containernetworking-plugins')
    expect(harness.podman_default_packages).to include('shadow-utils')
  end

  it 'keeps the CNI plugins on EL9' do
    harness.node = node_for('rhel', 'almalinux').merge('platform_version' => '9.6')
    expect(harness.podman_default_packages).to include('containernetworking-plugins')
  end

  it 'skips the CNI plugins on Amazon Linux' do
    harness.node = node_for('amazon', 'amazon')
    expect(harness.podman_default_packages).to eq(
      %w(podman netavark aardvark-dns podman-docker shadow-utils)
    )
  end

  it 'always installs podman and the network stack' do
    harness.node = node_for('debian')
    expect(harness.podman_default_packages).to include('podman', 'netavark', 'aardvark-dns')
  end
end
