# frozen_string_literal: true

require 'spec_helper'

describe 'test::kube' do
  platform 'ubuntu', '24.04'
  step_into :podman_kube_play, :podman_kube_generate

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_kube_play podman_kube_generate)
    ).converge(described_recipe)
  end

  before do
    stub_podman(
      stdout_for: {
        'secret inspect' => JSON.generate([{ 'Spec' => { 'Name' => 'inline-secret' }, 'SecretData' => "GREETING=hi\n" }]),
      }
    )
    chef_run
  end

  it 'generates a manifest to stdout and writes the file itself' do
    expect(chef_run).to generate_podman_kube_generate('kube-source').with(destination: '/tmp/kube-source.yaml')
    expect(podman_commands).to include(a_string_matching(/kube generate kube-source$/))
    expect(podman_commands).not_to include(a_string_matching(/kube generate .*--filename/))
    expect(chef_run).to create_file('/tmp/kube-source.yaml')
  end

  it 'plays with --replace and tears down without it' do
    expect(chef_run).to play_podman_kube_play('/tmp/kube-source.yaml')
    expect(chef_run).to teardown_podman_kube_play('/tmp/kube-source.yaml')
    expect(podman_commands).to include(a_string_matching(%r{kube play --replace /tmp/kube-source\.yaml}))
    expect(podman_commands).to include(a_string_matching(%r{kube down /tmp/kube-source\.yaml}))
    expect(podman_commands).not_to include(a_string_matching(/kube down --replace/))
  end

  it 'reads an inline manifest from stdin as a positional dash' do
    inline = podman_commands.find { |command| command.include?('kube play') && command.include?(' -') }
    expect(inline).not_to include('--file')
  end

  it 'folds namespace, env and secrets into the inline manifest' do
    pod = inline_documents.find { |document| document['kind'] == 'Pod' }
    expect(pod.dig('metadata', 'namespace')).to eq('chef-test')
    expect(pod.dig('spec', 'containers', 0, 'env')).to eq([{ 'name' => 'GREETING', 'value' => 'hello' }])
    expect(pod.dig('spec', 'containers', 0, 'envFrom')).to eq([{ 'secretRef' => { 'name' => 'inline-secret' } }])
  end

  it 'adds the referenced secret as a Secret document' do
    secret = inline_documents.find { |document| document['kind'] == 'Secret' }
    expect(secret['metadata']).to eq('name' => 'inline-secret', 'namespace' => 'chef-test')
    expect(secret['stringData']).to eq('GREETING' => 'hi')
  end

  def inline_documents
    YAML.load_stream(podman_inputs.last)
  end
end
