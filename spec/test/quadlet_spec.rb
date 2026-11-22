# frozen_string_literal: true

require 'spec_helper'

describe 'test::quadlet' do
  platform 'ubuntu', '24.04'

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_quadlet)
    ).converge(described_recipe)
  end

  # Report the units as stopped so the start guard runs the command.
  before { stub_podman(failing_for: ['systemctl is-active', 'systemctl is-enabled']) }

  it 'writes the quadlet unit' do
    expect(chef_run).to create_file('/etc/containers/systemd/chef-test.container').with(
      mode: '0644'
    )
  end

  it 'derives the generated service name from the unit type' do
    expect(chef_run).to create_file('/etc/containers/systemd/chef-net.network')
    expect(chef_run).to run_execute('start chef-net-network.service')
  end

  it 'drops the type suffix from an instanced unit service name' do
    expect(chef_run).to create_file('/etc/containers/systemd/chef-template@.container')
    expect(chef_run).to run_execute('start chef-template@one.service')
  end

  it 'names the container after the unit and expands the instance' do
    expect(chef_run).to create_file('/etc/containers/systemd/chef-template@.container')
      .with(content: a_string_including("ContainerName=systemd-chef-template-%i\n"))
  end

  it 'keeps a ContainerName from the unit content' do
    content = chef_run.find_resource(:file, '/etc/containers/systemd/chef-custom.container').content
    expect(content).to match(/^ContainerName=custom-name$/)
    expect(content.scan(/^ContainerName=/).size).to eq(1)
  end

  it 'only starts a unit that systemd already generated' do
    # `systemctl enable` refuses generated units, so an enabled but stopped
    # unit is only started.
    runner = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_quadlet)
    )
    stub_podman(stdout_for: { 'systemctl is-enabled' => "generated\n" },
                failing_for: ['systemctl is-active'])
    podman_commands.clear
    runner.converge(described_recipe)
    command = runner.find_resource(:execute, 'enable chef-test.service').command
    expect(command).to end_with('systemctl start chef-test.service')
    expect(command).not_to include('enable')
  end

  it 'enables a disabled unit' do
    runner = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_quadlet)
    )
    stub_podman(stdout_for: { 'systemctl is-enabled' => "disabled\n" },
                failing_for: ['systemctl is-active'])
    runner.converge(described_recipe)
    expect(runner.find_resource(:execute, 'enable chef-test.service').command)
      .to end_with('systemctl enable --now chef-test.service')
  end

  it 'only starts and enables units that are not up yet' do
    %w(start enable).each do |action|
      execute = chef_run.find_resource(:execute, "#{action} chef-test.service")
      expect(execute.not_if).not_to be_empty
    end
  end

  %i(enable start stop delete).each do |action|
    it "declares the #{action} action" do
      expect(chef_run).to send("#{action}_podman_quadlet", 'chef-test')
    end
  end
end

describe 'test::quadlet_invalid' do
  platform 'ubuntu', '24.04'

  before { stub_podman }

  it 'requires unit content' do
    expect do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04', step_into: %w(podman_quadlet))
                          .converge(described_recipe)
    end.to raise_error(Chef::Exceptions::ValidationFailed, /needs unit content/)
  end
end
