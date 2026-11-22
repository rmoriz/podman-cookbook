# frozen_string_literal: true

require 'spec_helper'

describe 'test::quadlet_missing' do
  platform 'ubuntu', '24.04'
  step_into :podman_quadlet

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_quadlet)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'writes the minimal unit' do
    expect(chef_run).to create_file('/etc/containers/systemd/chef-empty.container').with(
      content: satisfy { |content| content.include?('Image=docker.io/library/busybox:latest') }
    )
  end
end
