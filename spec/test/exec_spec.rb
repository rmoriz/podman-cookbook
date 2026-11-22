# frozen_string_literal: true

require 'spec_helper'

describe 'test::exec' do
  platform 'ubuntu', '24.04'
  step_into :podman_exec

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_exec)
    ).converge(described_recipe)
  end

  before do
    stub_podman(exit_codes: { 'exit 3' => 3, 'exit\\ 3' => 3 })
    chef_run
  end

  it 'runs the command inside the container' do
    expect(podman_commands).to include(a_string_matching(/podman exec exec-target sh -c/))
  end

  it 'accepts the declared exit code' do
    expect(chef_run).to run_podman_exec('failing command').with(returns: [3])
  end

  it 'falls back to the container object' do
    expect(podman_commands).to include(a_string_matching(/podman exec exec-target true/))
  end
end
