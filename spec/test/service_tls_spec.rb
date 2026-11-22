# frozen_string_literal: true

require 'spec_helper'

describe 'test::service_tls' do
  platform 'ubuntu', '24.04'
  step_into :podman_service_manager_execute

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_service_manager_execute)
    ).converge(described_recipe)
  end

  before do
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv4.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv6.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_service_running('/run/podman-tls.pid', '/usr/local/libexec/podman-tls-wait-ready')
    stub_command('test -s /etc/podman/ca.crt').and_return(true)
    stub_command('test -s /etc/podman/client.crt').and_return(true)
    stub_command('/usr/local/libexec/podman-tls-wait-ready').and_return(true)
    stub_podman
  end

  it 'falls back to the client certificate pair for the API server' do
    code = chef_run.bash('start podman-tls').code
    expect(code).to include('--tls-cert /etc/podman/client.crt')
    expect(code).to include('--tls-key /etc/podman/client.key')
    expect(code).to include('--tls-client-ca /etc/podman/ca.crt')
  end

  it 'creates the directory the readiness probe is written to' do
    expect(chef_run).to create_directory('/usr/local/libexec').with(recursive: true)
  end

  it 'installs curl for the TLS readiness probe' do
    expect(chef_run).to install_package('curl')
  end

  it 'gives the readiness probe the client certificate' do
    waiter = chef_run.find_resource(:template, '/usr/local/libexec/podman-tls-wait-ready')

    expect(waiter.variables[:podman_tls_cert]).to eq('/etc/podman/client.crt')
    expect(waiter.variables[:podman_tls_key]).to eq('/etc/podman/client.key')
    expect(waiter.variables[:podman_socket]).to eq('/run/podman/podman.sock')
  end

  # `podman system service` only learned the TLS flags in Podman 5.
  context 'on a build without the TLS flags' do
    let(:chef_run) do
      stub_podman(stdout_for: { 'system service --help' => '  -t, --time uint   Time until the service session expires' })
      ChefSpec::SoloRunner.new(
        platform: 'ubuntu',
        version: '24.04',
        step_into: %w(podman_service_manager_execute)
      ).converge(described_recipe)
    end

    it 'serves the socket without TLS' do
      code = chef_run.bash('start podman-tls').code
      expect(code).not_to include('--tls-cert')
      expect(code).not_to include('--tls-client-ca')
      expect(chef_run).not_to install_package('curl')
    end
  end
end

describe 'test::service_tls_systemd' do
  platform 'ubuntu', '24.04'
  step_into :podman_service_manager_systemd

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_service_manager_systemd)
    ).converge(described_recipe)
  end

  before do
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv4.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv6.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_command('test -s /etc/podman/ca.crt').and_return(true)
    stub_command('test -s /etc/podman/client.crt').and_return(true)
    stub_podman
  end

  it 'installs curl for the TLS readiness probe' do
    expect(chef_run).to install_package('curl')
  end

  it 'gives the readiness probe the client certificate' do
    waiter = chef_run.find_resource(:template, '/usr/local/libexec/podman-tls-wait-ready')

    expect(waiter.variables[:podman_tls_cert]).to eq('/etc/podman/client.crt')
    expect(waiter.variables[:podman_socket]).to eq('/run/podman/podman.sock')
  end

  it 'creates the directory the readiness probe is written to' do
    expect(chef_run).to create_directory('/usr/local/libexec').with(recursive: true)
  end

  it 'puts the TLS flags into the unit' do
    expect(chef_run).to create_template('/etc/systemd/system/podman-tls.service').with(
      variables: a_hash_including(
        tls_server_cert: '/etc/podman/client.crt',
        tls_ca_cert: '/etc/podman/ca.crt'
      )
    )
  end
end
