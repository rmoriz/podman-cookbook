# frozen_string_literal: true

require 'spec_helper'

describe 'test::smoke' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before { stub_podman }

  it 'pulls, runs, execs into and deletes a container' do
    expect(chef_run).to pull_podman_image('busybox')
    expect(chef_run).to run_podman_container('smoke')
    expect(chef_run).to run_podman_exec('smoke echo')
    expect(chef_run).to delete_podman_container('smoke')
  end
end
