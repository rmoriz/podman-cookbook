# frozen_string_literal: true

require 'spec_helper'

describe 'test::container' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe) }

  before { stub_podman }

  it 'creates a container without starting it' do
    expect(chef_run).to create_podman_container('hello-world').with(
      repo: 'busybox',
      command: ['/bin/echo', 'hello']
    )
  end

  it 'runs a container only when missing' do
    expect(chef_run).to run_if_missing_podman_container('alpine_ls').with(
      repo: 'alpine',
      command: ['ls', '-la', '/']
    )
  end

  it 'runs a container' do
    expect(chef_run).to run_podman_container('busybox_ls')
  end

  it 'sets labels, env and restart policy' do
    expect(chef_run).to run_podman_container('labeled').with(
      labels: { 'chef' => 'test', 'role' => 'worker' },
      env: ['FOO=bar'],
      restart_policy: 'unless-stopped'
    )
  end

  it 'selects the OCI runtime per container' do
    expect(chef_run).to run_podman_container('own-runtime').with(runtime: 'crun')
  end

  it 'passes the runtime to podman' do
    step_into_runner = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_container)
    )
    stub_podman(stdout_for: { 'container inspect' => JSON.generate('State' => { 'Running' => true }) })
    podman_commands.clear
    step_into_runner.converge(described_recipe)
    create = podman_commands.find { |command| command.include?('--name own-runtime') }
    expect(create).to include('--runtime crun')
  end

  it 'passes annotations to podman in sorted order' do
    step_into_runner = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_container)
    )
    stub_podman(stdout_for: { 'container inspect' => JSON.generate('State' => { 'Running' => true }) })
    podman_commands.clear
    step_into_runner.converge(described_recipe)
    create = podman_commands.find { |command| command.include?('--name own-runtime') }
    expect(create).to include('--annotation krun.cpus\=2 --annotation krun.ram_mib\=2048')
  end

  it 'coerces short port specs into the inspect form' do
    expect(chef_run).to create_podman_container('published').with(
      port_bindings: { '80/tcp' => [{ 'HostIp' => '0.0.0.0', 'HostPort' => '8080' }] },
      exposed_ports: { '443/tcp' => {} }
    )
  end

  it 'stops and deletes containers' do
    expect(chef_run).to stop_podman_container('stopped')
    expect(chef_run).to delete_podman_container('stopped')
  end

  it 'executes a command in a container' do
    expect(chef_run).to run_podman_exec('write file').with(
      container: 'exec-target',
      command: ['sh', '-c', 'echo hi > /tmp/hi']
    )
  end

  it 'supports the full lifecycle actions' do
    expect(chef_run).to pause_podman_container('lifecycle')
    expect(chef_run).to unpause_podman_container('lifecycle')
    expect(chef_run).to restart_podman_container('lifecycle')
    expect(chef_run).to reload_podman_container('lifecycle')
    expect(chef_run).to redeploy_podman_container('lifecycle')
    expect(chef_run).to kill_podman_container('lifecycle')
    expect(chef_run).to commit_podman_container('lifecycle')
    expect(chef_run).to export_podman_container('lifecycle').with(outfile: '/tmp/lifecycle.tar')
    expect(chef_run).to delete_podman_container('lifecycle').with(force: true, remove_volumes: true)
  end
end
