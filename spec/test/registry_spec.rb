# frozen_string_literal: true

require 'spec_helper'

describe 'test::registry' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before { stub_podman }

  it 'skips the login when the stored user already matches' do
    allow_any_instance_of(Chef::Resource).to receive(:podman_shell_out) do |_instance, *args, **_opts|
      PodmanShellResult.new(stdout: 'chef', exitstatus: args.include?('--get-login') ? 0 : 1)
    end

    runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04', step_into: %w(podman_registry))
    expect(runner.converge(described_recipe)).to login_podman_registry('127.0.0.1:5000')
  end

  it 'logs in to the registry' do
    expect(chef_run).to login_podman_registry('127.0.0.1:5000').with(
      username: 'chef',
      password: 'secret',
      email: 'chef@example.com',
      tls_verify: false
    )
  end

  it 'skips the TLS check for the plain-HTTP registry' do
    runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04', step_into: %w(podman_registry))
    allow_any_instance_of(Chef::Resource).to receive(:podman_shell_out) do |_instance, *args, **_opts|
      PodmanShellResult.new(stdout: '', exitstatus: args.include?('--get-login') ? 1 : 0)
    end

    runner.converge(described_recipe)
    expect(podman_commands).to include(a_string_matching(/login --password-stdin --tls-verify\\=false --username chef 127\.0\.0\.1:5000/))
  end
end
