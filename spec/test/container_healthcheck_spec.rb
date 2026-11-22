# frozen_string_literal: true

require 'spec_helper'

describe 'test::container_healthcheck' do
  platform 'ubuntu', '24.04'
  step_into :podman_container

  let(:health_check) do
    {
      'Test' => ['CMD-SHELL', 'curl\\ -f\\ http://localhost'],
      'Interval' => 1_500_000_000,
      'Timeout' => 5_000_000_000,
      'Retries' => 3,
      'StartPeriod' => 10_000_000_000,
    }
  end

  let(:inspect_document) do
    JSON.generate(
      [{
        'Id' => 'abc123',
        'Config' => {
          'Image' => 'docker.io/library/busybox:latest',
          'Cmd' => %w(sleep 300),
          'Entrypoint' => nil,
          'Env' => [],
          'Labels' => {},
          'Hostname' => nil,
          'Domainname' => '',
          'User' => nil,
          'WorkingDir' => nil,
          'Tty' => false,
          'OpenStdin' => false,
          'ExposedPorts' => {},
          'Healthcheck' => health_check,
        },
        'HostConfig' => {
          'Binds' => [], 'CapAdd' => nil, 'CapDrop' => nil, 'CgroupParent' => '',
          'CgroupnsMode' => 'private', 'Devices' => [], 'Dns' => [], 'DnsSearch' => [],
          'ExtraHosts' => nil, 'IpcMode' => 'shareable', 'Init' => nil, 'Memory' => 0,
          'MemorySwap' => nil, 'MemorySwappiness' => 0, 'MemoryReservation' => 0,
          'NanoCpus' => 0, 'NetworkMode' => 'bridge', 'OomKillDisable' => false,
          'OomScoreAdj' => -500, 'PidMode' => '', 'PortBindings' => {}, 'Privileged' => false,
          'PublishAllPorts' => false, 'ReadonlyRootfs' => false,
          'RestartPolicy' => { 'Name' => nil, 'MaximumRetryCount' => 0 },
          'SecurityOpt' => nil, 'ShmSize' => 67_108_864, 'Sysctls' => {}, 'Tmpfs' => {},
          'Ulimits' => nil, 'UsernsMode' => '', 'UTSMode' => '', 'VolumesFrom' => nil,
          'Runtime' => nil
        },
      }]
    )
  end

  def converge_with(document)
    stub_podman(stdout_for: { 'container inspect' => document })
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_container)
    ).converge(described_recipe)
  end

  it 'treats nanosecond durations from inspect as unchanged' do
    converge_with(inspect_document)
    expect(podman_commands.grep(/podman create/)).to be_empty
  end

  it 'recreates the container when the health command changes' do
    health_check['Test'] = ['CMD-SHELL', 'wget\\ -q\\ --spider\\ http://localhost']
    converge_with(inspect_document)
    expect(podman_commands.any? { |command| command.include?('podman rm') }).to be(true)
  end
end
