# frozen_string_literal: true

require 'spec_helper'

describe 'test::install_tarball' do
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

  # The file cache path differs between building the runner and reading the
  # resource, so look the download up in the collection instead of rebuilding
  # the path.
  def tarball_resource
    chef_run.resource_collection.to_a.find { |resource| resource.is_a?(Chef::Resource::RemoteFile) }
  end

  it 'downloads the static tarball with its checksum' do
    expect(tarball_resource.name).to end_with('podman-6.2.0-amd64.tar.gz')
    expect(tarball_resource.checksum).to eq('981bcee9ff6a07b3a3e22b9ea98c9aa10bcf67bac2abdc3049595267122378be')
  end

  it 'extracts the tarball after the download' do
    names = chef_run.resource_collection.to_a.map(&:to_s)
    expect(names.index(tarball_resource.to_s)).to be < names.index('execute[extract podman tarball]')
    expect(chef_run.execute('extract podman tarball').command).to include('strip-components')
    expect(chef_run.execute('extract podman tarball').command).to end_with('-C / podman-linux-amd64/usr')
  end

  it 'only unpacks usr so the distribution /etc survives' do
    expect(chef_run.execute('extract podman tarball').command).to end_with('podman-linux-amd64/usr')
  end

  it 'creates the prefix before the download' do
    names = chef_run.resource_collection.to_a.map(&:to_s)
    expect(names.index('directory[/]')).to be < names.index(tarball_resource.to_s)
  end

  it 'extracts because the binary is missing' do
    expect(chef_run).to run_execute('extract podman tarball')
  end

  it 'leaves an up to date binary alone' do
    runner = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_installation_tarball)
    )
    stub_podman(stdout_for: { 'podman --version' => "podman version 6.2.0\n" })
    expect(runner.converge(described_recipe)).to_not run_execute('extract podman tarball')
  end

  it 'links the binary and writes the nodocker marker' do
    expect(chef_run).to create_link('/usr/bin/podman').with(to: '/usr/local/bin/podman')
    expect(chef_run).to create_file('/etc/containers/nodocker')
  end

  it 'pins the runtime to the crun the bundle ships' do
    expect(chef_run).to create_file('/etc/containers/containers.conf.d/10-podman-tarball-runtime.conf')
      .with(content: a_string_including('runtime = "/usr/local/bin/crun"'))
  end
end

describe 'test::install_tarball_delete' do
  platform 'ubuntu', '24.04'
  step_into :podman_installation_tarball

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_installation_tarball)
    ).converge(described_recipe)
  end

  before do
    stub_podman
    chef_run
  end

  it 'removes the link, the binary, the runtime pin and the nodocker marker' do
    expect(chef_run).to delete_link('/usr/bin/podman')
    expect(chef_run).to delete_file('/usr/local/bin/podman')
    expect(chef_run).to delete_file('/etc/containers/containers.conf.d/10-podman-tarball-runtime.conf')
    expect(chef_run).to delete_file('/etc/containers/nodocker')
  end
end
