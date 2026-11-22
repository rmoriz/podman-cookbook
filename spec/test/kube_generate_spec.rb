# frozen_string_literal: true

require 'spec_helper'

describe 'test::kube_generate' do
  platform 'ubuntu', '24.04'
  step_into :podman_kube_generate

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_kube_generate)
    ).converge(described_recipe)
  end

  before do
    stub_podman(
      stdout_for: {
        'kube generate' => "apiVersion: v1\nmetadata:\n  creationTimestamp: \"2026-01-01T00:00:00Z\"\n  name: web-pod\nport:\n  nodePort: 31000\n",
      }
    )
    chef_run
  end

  it 'generates with the kind and replicas flags' do
    command = podman_commands.find { |entry| entry.include?('kube generate') }
    expect(command).to include('--type deployment')
    expect(command).to include('--replicas 2')
    expect(command).not_to include('--filename')
    expect(command).to include('--service')
    expect(command).to end_with(' web')
  end

  it 'writes the generated YAML to the destination without its timestamp' do
    expect(chef_run).to create_file('/tmp/web.yaml').with(content: "apiVersion: v1\nmetadata:\n  name: web-pod\nport:\n")
  end
end
