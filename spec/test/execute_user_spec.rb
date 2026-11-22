# frozen_string_literal: true

require 'spec_helper'

describe 'test::execute_user' do
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
    allow(Etc).to receive(:getpwnam).with('podman').and_return(double(uid: 1001, dir: '/home/podman'))
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv4.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv6.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_service_running('/run/podman-rootless.pid', '/usr/local/libexec/podman-rootless-wait-ready')
    stub_command('/usr/local/libexec/podman-rootless-wait-ready').and_return(true)
    stub_command('sh -c "test -z \"$(find /home/podman ! -user podman -print -quit)\""').and_return(true)
    stub_podman
  end

  it 'starts the service on the rootless runtime socket' do
    expect(chef_run).to run_bash('start podman-rootless').with(
      code: a_string_including('unix:///run/user/1001/podman/podman.sock')
    )
  end

  it 'owns the user runtime directory like logind does' do
    expect(chef_run).to create_directory('/run/user/1001').with(
      owner: 'podman',
      group: 'podman',
      mode: '0700'
    )
  end

  it 'creates the directory the readiness probe is written to' do
    expect(chef_run).to create_directory('/usr/local/libexec').with(recursive: true)
  end

  it 'creates the socket directory only after the user manager is up' do
    code = chef_run.bash('start podman-rootless').code
    expect(code).to include('install -d -o podman -g podman /run/user/1001/podman')
    expect(code.index('systemd/private')).to be < code.index('install -d')
  end

  it 'retries the start until the daemon answers' do
    code = chef_run.bash('start podman-rootless').code
    expect(code).to include('for attempt in $(seq')
    expect(code.index('install -d')).to be < code.index('su -s /bin/sh podman -c')
    expect(code.index('su -s /bin/sh podman -c')).to be < code.index('/usr/local/libexec/podman-rootless-wait-ready && exit 0')
  end

  it 'runs the service as the socket owner' do
    expect(chef_run.bash('start podman-rootless').code).to include('su -s /bin/sh podman -c')
  end

  it 'hands the user environment to the daemon' do
    code = chef_run.bash('start podman-rootless').code
    expect(code).to include('HOME=/home/podman')
    expect(code).to include('XDG_RUNTIME_DIR=/run/user/1001')
    expect(code).to include('XDG_CONFIG_HOME=/home/podman/.config')
    expect(code).to include('USER=podman LOGNAME=podman')
  end

  it 'clears a socket left behind by a dead manager' do
    expect(chef_run.execute('remove stale socket /run/user/1001/podman/podman.sock').command).to eq(
      ['rm', '-f', '/run/user/1001/podman/podman.sock']
    )
  end

  it 'does not leak the systemd time specifier into the command' do
    expect(chef_run.bash('start podman-rootless').code).not_to include('%t')
  end
end
