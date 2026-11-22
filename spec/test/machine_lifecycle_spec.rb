# frozen_string_literal: true

require 'spec_helper'

describe 'test::machine_lifecycle' do
  platform 'ubuntu', '24.04'
  step_into :podman_machine

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    ).converge(described_recipe)
  end

  # The machine state changes while the recipe runs: absent, then existing and
  # stopped, then running. Without that, the guards would skip stop and remove.
  before do
    stub_podman
    allow_any_instance_of(Chef::Provider).to receive(:shell_out) do |_instance, *args, **_opts|
      command = args.join(' ')
      podman_commands << command
      state = machine_state_for(command) if command.include?('machine inspect')
      PodmanShellResult.new(stdout: state, exitstatus: 0)
    end
  end

  def machine_state_for(_command)
    ran = ->(action) { podman_commands.any? { |c| c.include?(" machine #{action} ") } }
    return '' if ran.call('rm')
    return JSON.generate([{ 'Name' => 'ci', 'State' => 'stopped' }]) if ran.call('stop')
    return JSON.generate([{ 'Name' => 'ci', 'State' => 'running' }]) if ran.call('start')
    return '' unless ran.call('init')

    JSON.generate(
      [{ 'Name' => 'ci', 'State' => 'stopped',
         'ConfigPath' => { 'Path' => '/home/podmanmachine/.config/containers/podman/machine/qemu/ci.json' } }]
    )
  end

  it 'initialises, starts, stops and removes the machine in order' do
    chef_run
    machine_commands = podman_commands.grep(/ machine /).grep_v(/ machine inspect /)

    expect(machine_commands).to match(
      [
        satisfy { |c| c.include?(' machine init ') && c.end_with?(' ci') && !c.include?('--now') },
        satisfy { |c| c.end_with?(' machine start ci') },
        satisfy { |c| c.end_with?(' machine stop ci') },
        satisfy { |c| c.end_with?(' machine rm --force ci') },
      ]
    )
  end
end
