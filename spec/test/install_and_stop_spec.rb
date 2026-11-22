# frozen_string_literal: true

require 'spec_helper'

describe 'test::install_and_stop' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before { stub_podman }

  it 'drops a stale lock file of another Podman build' do
    expect(chef_run).to delete_file('/dev/shm/libpod_lock')
  end

  it 'installs, starts and stops podman' do
    expect(chef_run).to create_podman_service('default')
    expect(chef_run).to start_podman_service('default')
    expect(chef_run).to stop_podman_service('default')
  end
end
