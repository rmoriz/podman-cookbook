# frozen_string_literal: true

require 'spec_helper'

describe 'test::install_script' do
  platform 'ubuntu', '24.04'
  step_into :podman_installation_script

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_installation_script)
    ).converge(described_recipe)
  end

  before do
    stub_command('sh -c "command -v podman"').and_return(false)
    stub_command('sh -c "test -e /usr/bin/podman -o -L /usr/bin/podman"').and_return(true)
    stub_command('sh -c "test -e /usr/local/bin/podman -o -L /usr/local/bin/podman"').and_return(true)
    stub_podman
    chef_run
  end

  it 'drops the stale static binaries first' do
    expect(chef_run).to run_execute('remove /usr/bin/podman')
    expect(chef_run).to run_execute('remove /usr/local/bin/podman')
  end

  it 'drops the bundled installer' do
    expect(chef_run).to create_cookbook_file('/usr/local/sbin/install-podman.sh').with(mode: '0755')
  end

  it 'runs the installer' do
    expect(chef_run).to run_execute('install podman')
  end

  it 'writes the nodocker marker' do
    expect(chef_run).to create_file('/etc/containers/nodocker').with(mode: '0644')
  end

  it 'is also provided as the generic podman_installation' do
    klass = Chef::Resource.resource_for_node(:podman_installation, chef_run.node)
    expect(klass.resource_name.to_s).to eq('podman_installation_script')
  end
end

describe 'test::install_script_delete' do
  platform 'ubuntu', '24.04'
  step_into :podman_installation_script, :podman_installation_tarball

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_installation_script podman_installation_tarball)
    ).converge(described_recipe)
  end

  before do
    stub_command('sh -c "command -v podman"').and_return(false)
    stub_podman
    chef_run
  end

  it 'removes the whole package set' do
    expect(chef_run).to remove_package('podman packages').with(
      package_name: %w(podman netavark aardvark-dns podman-docker containernetworking-plugins uidmap)
    )
  end

  it 'removes the installer and the nodocker marker' do
    expect(chef_run).to delete_file('/usr/local/sbin/install-podman.sh')
    expect(chef_run).to delete_file('/etc/containers/nodocker')
  end

  it 'also removes a tarball installation' do
    expect(chef_run).to delete_file('/usr/local/bin/podman')
    expect(chef_run).to delete_link('/usr/bin/podman')
  end
end
