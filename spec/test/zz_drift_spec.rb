# frozen_string_literal: true

require 'spec_helper'

describe 'test::zz_drift' do
  platform 'ubuntu', '24.04'
  step_into :podman_container

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_container)
    ).converge(described_recipe)
  end

  before { stub_podman }

  let(:annotations) do
    { 'io.podman.annotations.autoremove' => 'TRUE', 'krun.cpus' => '2', 'krun.ram_mib' => '2048' }
  end

  it 'folds the domain into the hostname' do
    chef_run
    create = podman_commands.find { |command| command.include?('--name drift-check') }
    expect(create).to include('--hostname app.example.com')
    expect(create).not_to include('--domainname')
  end

  it 'records links as labels because podman has no --link' do
    chef_run
    create = podman_commands.find { |command| command.include?('--name drift-check') }
    expect(create).not_to include('--link')
    expect(create).to include('--label podman_link_0\=db:database')
  end

  it 'moves the volume driver into the mount syntax' do
    chef_run
    create = podman_commands.find { |command| command.include?('--name drift-check') }
    expect(create).to include('--mount type\=volume,source\=appdata,destination\=/data,volume-driver\=local')
    expect(create).not_to include('--volume-driver')
  end

  context 'when the existing container already matches' do
    before do
      stub_podman(
        stdout_for: {
          'inspect' => JSON.generate(
            [{
              'Id' => 'abc123',
              'Config' => {
                'Image' => 'busybox:latest',
                'Cmd' => %w(sleep 300),
                'Env' => [],
                'Labels' => { 'podman_link_0' => 'db:database' },
                'Annotations' => annotations,
                'Hostname' => 'app.example.com',
                'User' => '',
                'WorkingDir' => '',
                'Tty' => false,
                'OpenStdin' => false,
                'AttachStdout' => false,
                'AttachStderr' => false,
                'AttachStdin' => false,
                'StdinOnce' => false,
              },
              'HostConfig' => {
                'Binds' => ['appdata:/data'],
                'Mounts' => [{ 'Type' => 'volume', 'Driver' => 'local', 'Source' => 'appdata', 'Destination' => '/data' }],
                'Devices' => [],
                'Dns' => [],
                'DnsSearch' => [],
                'IpcMode' => 'shareable',
                'Memory' => 0,
                'MemoryReservation' => 0,
                'MemorySwap' => 0,
                'NanoCpus' => 0,
                'NetworkMode' => 'bridge',
                'OomKillDisable' => false,
                'PortBindings' => {},
                'Privileged' => false,
                'PublishAllPorts' => false,
                'ReadonlyRootfs' => false,
                'ShmSize' => 67_108_864,
                'Sysctls' => {},
                'Tmpfs' => {},
                'UsernsMode' => '',
                'UTSMode' => '',
              },
              'State' => { 'Running' => false, 'StartedAt' => '2026-11-22T00:00:00Z' },
            }]
          ),
        }
      )
    end

    it 'does not recreate the container' do
      chef_run
      expect(podman_commands.grep(/container create/)).to be_empty
    end

    it 'treats annotations as a set and ignores podmans own' do
      chef_run
      expect(podman_commands.grep(/container create/)).to be_empty
    end
  end

  context 'when an annotation differs' do
    let(:annotations) { { 'krun.cpus' => '4' } }

    it 'recreates the container with the configured set' do
      chef_run
      create = podman_commands.find { |command| command.include?('--name drift-check') }
      expect(create).to include('--annotation krun.cpus\=2')
    end
  end
end
