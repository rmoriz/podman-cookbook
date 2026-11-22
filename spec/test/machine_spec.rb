# frozen_string_literal: true

require 'spec_helper'

describe 'test::machine' do
  platform 'ubuntu', '24.04'
  step_into :podman_machine

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    ).converge(described_recipe)
  end

  before do
    stub_podman
    chef_run
  end

  it 'initializes the machine with its limits' do
    init = podman_commands.find { |command| command.include?('machine init') }
    expect(init).to include('--cpus 2')
    expect(init).to include('--memory 2048')
    expect(init).to include('--disk-size 20')
    expect(init).to include('--rootful')
    expect(init).to end_with(' ci')
    # The ignition file is repaired between init and the boot, so `--now` is not
    # used and the start is issued separately.
    expect(init).not_to include('--now')
  end

  it 'tolerates a start that reports the machine as already running' do
    race = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    )
    # The failed boot leaves the VM running, so the state flips to running.
    inspections = 0
    state = lambda do
      inspections += 1
      JSON.generate([{ 'Name' => 'ci', 'State' => inspections > 2 ? 'running' : 'stopped' }])
    end
    stub_podman(
      stdout_for: { 'machine inspect' => state },
      failing_for: ['machine start'],
      stderr_for: { 'machine start' => 'Error: unable to start "ci": already running' }
    )
    podman_commands.clear
    expect { race.converge(described_recipe) }.not_to raise_error
  end

  it 'does not start a VM that is still up although Podman reports no state' do
    leftover = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    )
    stub_podman(stdout_for: { 'machine inspect' => JSON.generate([{ 'Name' => 'ci', 'State' => '' }]) })
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(a_string_matching(%r{/podman/ci_vm\.pid$})).and_return("4242\n")
    allow(Process).to receive(:kill).with(anything, 4242)
    podman_commands.clear
    leftover.converge(described_recipe)

    expect(podman_commands.grep(/machine start/)).to be_empty
  end

  it 'leaves an existing machine alone' do
    existing = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    )
    stub_podman(stdout_for: { 'machine inspect' => JSON.generate([{ 'Name' => 'ci', 'State' => 'stopped' }]) })
    podman_commands.clear
    existing.converge(described_recipe)

    expect(podman_commands.grep_v(/machine inspect/)).to be_empty
  end
end

describe 'test::machine_lifecycle' do
  platform 'ubuntu', '24.04'
  step_into :podman_machine

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    ).converge(described_recipe)
  end

  before do
    stub_podman(stdout_for: { 'machine inspect' => JSON.generate([{ 'Name' => 'ci', 'State' => 'stopped' }]) })
    chef_run
  end

  it 'starts the stopped machine' do
    expect(podman_commands).to include(a_string_matching(/machine start ci$/))
  end

  it 'tightens a world-readable identity file before booting' do
    identity = '/home/podmanmachine/.ssh/ci'
    reader = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    )
    stub_podman(
      stdout_for: { 'machine inspect' => JSON.generate([{ 'Name' => 'ci', 'State' => 'stopped',
                                                          'SSHConfig' => { 'IdentityPath' => identity, 'Port' => 22 } }]) }
    )
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(identity).and_return(true)
    allow(File).to receive(:stat).and_call_original
    allow(File).to receive(:stat).with(identity).and_return(double(mode: 0o100644))
    allow(File).to receive(:chmod)
    reader.converge(described_recipe)

    expect(File).to have_received(:chmod).with(0o600, identity)
  end

  it 'repairs the guest subuid files and retries when only the post-boot step failed' do
    broken = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    )
    # The machine only exists once init ran, and the retried boot leaves it
    # running, which a later action has to see.
    inspections = 0
    state = lambda do
      inspections += 1
      next '' if inspections == 1

      JSON.generate(
        [{ 'Name' => 'ci', 'State' => 'running',
           'SSHConfig' => { 'IdentityPath' => '/home/podmanmachine/.ssh/ci', 'Port' => 22,
                            'RemoteUsername' => 'core' } }]
      )
    end
    stub_podman(
      failing_for: ['machine start'],
      stderr_for: { 'machine start' => 'Error: machine did not transition into running state' },
      retried_for: ['machine start'],
      stdout_for: { 'machine inspect' => state }
    )
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(a_string_matching(%r{/podman/ci_vm\.pid$})).and_return("4242\n")
    allow(Process).to receive(:kill).with(anything, 4242)
    # The VM is gone once the restart killed it; the guest state says running,
    # so the retry is not polled through the pid.
    allow(Process).to receive(:kill).with(0, 4242) { raise Errno::ESRCH }
    podman_commands.clear
    broken.converge(described_recipe)

    expect(podman_commands).to include(a_string_matching(%r{^ssh -i /home/podmanmachine/\.ssh/ci -p 22 }))
    expect(podman_commands).to include(a_string_including('/etc/subgid'))
    expect(podman_commands.grep(/machine init/).size).to eq(1)
    expect(podman_commands.grep(/ machine start /).size).to eq(2)
  end

  it 'stops the port forwarder as well so the next boot can bind its port' do
    forwarder = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    )
    stub_podman(
      failing_for: ['machine start'],
      stderr_for: { 'machine start' => 'Error: machine did not transition into running state' },
      retried_for: ['machine start'],
      stdout_for: { 'machine inspect' => JSON.generate([{ 'Name' => 'ci', 'State' => 'stopped' }]) }
    )
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(a_string_matching(%r{/podman/ci_proxy\.pid$})).and_return("5151\n")
    allow(Process).to receive(:kill).with(anything, 5151)
    allow(Process).to receive(:kill).with(0, 5151) { raise Errno::ESRCH }
    forwarder.converge(described_recipe)

    expect(Process).to have_received(:kill).with('TERM', 5151)
  end

  it 'restarts a machine whose boot Podman gave up on' do
    slow = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    )
    # The failed boot leaves the VM running, so the state flips to running.
    inspections = 0
    state = lambda do
      inspections += 1
      JSON.generate([{ 'Name' => 'ci', 'State' => inspections > 2 ? 'running' : 'stopped' }])
    end
    stub_podman(
      stdout_for: { 'machine inspect' => state },
      failing_for: ['machine start'],
      stderr_for: { 'machine start' => 'Error: machine did not transition into running state' },
      retried_for: ['machine start']
    )
    podman_commands.clear
    slow.converge(described_recipe)

    expect(podman_commands.grep(/ machine start /).size).to eq(2)
    expect(podman_commands).to include(a_string_matching(/machine stop ci$/))
  end
end

describe 'test::machine_running' do
  platform 'ubuntu', '24.04'
  step_into :podman_machine

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    ).converge('test::machine_lifecycle')
  end

  before do
    stub_podman(stdout_for: { 'machine inspect' => JSON.generate([{ 'Name' => 'ci', 'State' => 'running' }]) })
    chef_run
  end

  it 'stops and force-removes the running machine' do
    expect(podman_commands).to include(a_string_matching(/machine stop ci$/))
    expect(podman_commands).to include(a_string_matching(/machine rm --force ci$/))
  end
end

describe 'test::machine ignition repair' do
  platform 'ubuntu', '24.04'
  step_into :podman_machine

  it 'repairs the ignition file before the first boot' do
    runner = ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_machine)
    )
    dir = '/var/lib/podmanmachine/.config/containers/podman/machine/qemu'
    path = "#{dir}/ci.ign"
    document = {
      'storage' => { 'files' => [{ 'path' => '/etc/subuid', 'contents' => { 'source' => 'data:,core:1:2' } }] },
      'systemd' => {
        'units' => [
          { 'name' => 'ready.service', 'contents' => "Requires=dev-virtio\\\\x2dports-vport1p1.device\n" },
          { 'name' => 'other.service', 'contents' => "After=dev-virtio\\\\x2dports-vport1p1.device\n" },
        ],
      },
    }
    inspections = 0
    state = lambda do
      inspections += 1
      next '' if inspections == 1

      JSON.generate([{ 'Name' => 'ci', 'State' => 'stopped', 'ConfigPath' => { 'Path' => "#{dir}/ci.json" } }])
    end
    stub_podman(stdout_for: { 'machine inspect' => state })

    written = nil
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(path).and_return(true)
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(path).and_return(JSON.generate(document))
    allow(File).to receive(:write) { |_file, content| written = content }
    runner.converge('test::machine')

    repaired = JSON.parse(written)
    expect(repaired['storage']['files'].first['contents']['source']).to end_with('%0A')
    expect(repaired['systemd']['units'].first['contents']).to include('Requires=dev-vport1p1.device')
    expect(repaired['systemd']['units'].last['contents']).to include('dev-virtio')
  end
end
