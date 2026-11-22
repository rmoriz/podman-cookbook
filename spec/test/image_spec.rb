# frozen_string_literal: true

require 'spec_helper'

describe 'test::image' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before { stub_podman }

  it 'pulls an image' do
    expect(chef_run).to pull_podman_image('busybox')
  end

  it 'pulls an image only when missing' do
    expect(chef_run).to pull_if_missing_podman_image('alpine').with(tag: 'latest')
  end

  it 'builds an image only when missing' do
    expect(chef_run).to build_if_missing_podman_image('test-build').with(source: '/tmp/Dockerfile')
  end

  it 'replaces an existing archive through a temporary file' do
    allow(FileUtils).to receive(:mv)
    runner = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_image)
    )
    stub_podman
    podman_commands.clear
    runner.converge(described_recipe)
    expect(podman_commands).to include(
      a_string_matching(%r{save --output /tmp/busybox\.tar\.tmp busybox:latest})
    )
    expect(FileUtils).to have_received(:mv).with('/tmp/busybox.tar.tmp', '/tmp/busybox.tar')
  end

  it 'saves and loads images' do
    expect(chef_run).to save_podman_image('busybox').with(destination: '/tmp/busybox.tar')
    expect(chef_run).to load_podman_image('busybox-loaded').with(source: '/tmp/busybox.tar')
  end

  it 'tags an image' do
    expect(chef_run).to tag_podman_tag('busybox').with(
      target_tag: 'latest',
      to_repo: 'busybox',
      to_tag: 'chef-test'
    )
  end

  it 'imports an image' do
    expect(chef_run).to import_podman_image('busybox-imported').with(source: '/tmp/busybox.tar')
  end

  it 'pushes an image to the local registry' do
    expect(chef_run).to push_podman_image('127.0.0.1:5003/busybox').with(tag: 'pushed', tls_verify: false)
  end

  it 'marks the local registry insecure' do
    expect(chef_run).to create_file('/etc/containers/registries.conf.d/50-chef-test-registry.conf')
      .with(content: a_string_matching(/insecure = true/))
  end

  it 'runs a registry to push to' do
    expect(chef_run).to run_podman_container('image-registry').with(
      port_bindings: { '5000/tcp' => [{ 'HostIp' => '0.0.0.0', 'HostPort' => '5003' }] }
    )
  end

  it 'removes an image' do
    expect(chef_run).to remove_podman_image('busybox').with(tag: 'chef-test', force: true)
  end
end

describe 'test::image_build' do
  platform 'ubuntu', '24.04'
  step_into :podman_image

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_image)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'passes a Dockerfile through --file with its directory as context' do
    chef_run
    expect(podman_commands).to include(a_string_matching(%r{build --tag chef-build:latest --rm\\=false --file /tmp/Dockerfile.build /tmp}))
  end
end
