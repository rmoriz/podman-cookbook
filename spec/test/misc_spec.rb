# frozen_string_literal: true

require 'spec_helper'

describe 'test::misc' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before { stub_podman }

  it 'installs from the bundled script' do
    expect(chef_run).to create_podman_installation_script('script')
  end

  it 'installs from the static tarball' do
    expect(chef_run).to create_podman_installation_tarball('tarball').with(version: '6.2.0')
  end

  it 'starts the execute service manager' do
    expect(chef_run).to start_podman_service_manager_execute('execute')
  end

  it 'generates a systemd unit' do
    expect(chef_run).to create_podman_generate_systemd('web-service').with(
      source: 'web',
      type: 'container',
      restart_policy: 'always'
    )
  end

  it 'plays an inline manifest' do
    expect(chef_run).to play_podman_kube_play('inline').with(manifest_content: /apiVersion: v1/)
  end

  it 'writes extra systemd units alongside the generated one' do
    expect(chef_run).to create_podman_generate_systemd('web-service').with(
      files: { 'extra.service' => "[Unit]\nDescription=extra\n" }
    )
  end
end
