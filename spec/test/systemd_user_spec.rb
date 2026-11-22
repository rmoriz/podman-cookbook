# frozen_string_literal: true

require 'spec_helper'

describe 'test::systemd_user' do
  platform 'ubuntu', '24.04'
  step_into :podman_service_manager_systemd

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_service_manager_systemd)
    ).converge(described_recipe)
  end

  before do
    allow(Etc).to receive(:getpwnam).with('podman').and_return(double(uid: 1001, dir: '/home/podman'))
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv4.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv6.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_podman(failing_for: ['is-enabled'])
    chef_run
  end

  it 'writes the units into the user manager directory' do
    expect(chef_run).to create_template('/home/podman/.config/systemd/user/podman-rootless.socket')
      .with(owner: 'podman', group: 'podman')
    expect(chef_run).to create_template('/home/podman/.config/systemd/user/podman-rootless.service')
      .with(owner: 'podman')
  end

  # Nested execute resources are not stepped into, so assert their command
  # instead of a recorded shell_out call.
  it 'keeps the user manager alive with lingering' do
    expect(chef_run.execute('enable lingering for podman').command)
      .to eq(%w(loginctl enable-linger podman))
    expect(chef_run.execute('enable lingering for podman').not_if).not_to be_nil
  end

  it 'waits for the user manager to appear' do
    expect(chef_run.execute('start user manager for podman').command).to eq(%w(systemctl start user@1001.service))
    expect(chef_run.execute('start user manager for podman').not_if).not_to be_nil
  end

  it 'reloads and restarts the user manager as that user' do
    expect(chef_run.execute('podman systemctl daemon-reload podman-rootless').user).to eq('podman')
    expect(chef_run.execute('podman systemctl restart podman-rootless').user).to eq('podman')
  end

  it 'enables the socket through the user manager' do
    expect(chef_run.execute('enable and start podman socket (user)').command)
      .to eq('systemctl --user enable --now podman-rootless.socket')
  end

  it 'writes the units of the mode-only recipe into the user home' do
    runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04', step_into: %w(podman_service_manager_systemd))
    allow(Etc).to receive(:getpwnam).with('chef').and_return(double(uid: 1002, dir: '/home/chef'))

    expect(runner.converge('test::systemd_user_mode_only')).to create_template('/home/chef/.config/systemd/user/podman-rootless.service')
  end

  it 'refuses user mode without a user' do
    expect do
      ChefSpec::SoloRunner.new(
        platform: 'ubuntu',
        version: '24.04',
        step_into: %w(podman_service_manager_systemd)
      ).converge('test::systemd_user_invalid')
    end.to raise_error(Chef::Exceptions::ValidationFailed, /needs a user/)
  end
end
