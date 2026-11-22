# frozen_string_literal: true

require 'spec_helper'

describe 'test::secret' do
  platform 'ubuntu', '24.04'
  step_into :podman_secret

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_secret)
    ).converge(described_recipe)
  end

  before do
    stub_podman(failing_for: ['secret exists'])
  end

  it 'creates a secret from a file' do
    expect(chef_run).to create_podman_secret('chef-secret-file').with(secret_file: '/tmp/chef-secret.txt')
    expect(podman_commands).to include(a_string_matching(%r{secret create chef-secret-file /tmp/chef-secret\.txt}))
  end

  it 'reads a value from stdin as a positional dash' do
    expect(chef_run).to create_podman_secret('chef-secret-value').with(value: 'new-secret')
    expect(podman_commands).to include(a_string_matching(/secret create chef-secret-value -$/))
  end

  it 'passes driver options, labels and no replace for a new secret' do
    chef_run
    command = podman_commands.find { |entry| entry.include?('secret create') && entry.include?('chef-secret-replaced') }
    expect(command).to include('--driver file')
    expect(command).to include('--driver-opts')
    expect(command).to include('/var/lib/podman/secrets')
    expect(command).to include('--label team')
    expect(command).not_to include('--replace')
  end

  it 'deletes a secret' do
    expect(chef_run).to delete_podman_secret('chef-secret-file')
  end

  context 'when the replaced secret carries different metadata' do
    before do
      stub_podman(
        failing_for: ['secret exists chef-secret-file', 'secret exists chef-secret-value'],
        stdout_for: {
          'secret inspect chef-secret-replaced' => JSON.generate(
            [{
              'Spec' => {
                'Name' => 'chef-secret-replaced',
                'Driver' => { 'Name' => 'file', 'Options' => { 'path' => '/var/lib/podman/secrets' } },
                'Labels' => { 'team' => 'dev' },
              },
            }]
          ),
        }
      )
    end

    it 'recreates it with --replace' do
      chef_run
      expect(podman_commands.grep(/secret create .*--replace chef-secret-replaced/).size).to eq(1)
    end
  end

  context 'when the replaced secret already carries the same metadata' do
    before do
      stub_podman(
        failing_for: ['secret exists chef-secret-file', 'secret exists chef-secret-value'],
        stdout_for: {
          'secret inspect chef-secret-replaced' => JSON.generate(
            [{
              'Spec' => {
                'Name' => 'chef-secret-replaced',
                'Driver' => { 'Name' => 'file', 'Options' => { 'path' => '/var/lib/podman/secrets' } },
                'Labels' => { 'team' => 'ops' },
              },
            }]
          ),
        }
      )
    end

    it 'does not create it again' do
      chef_run
      expect(podman_commands.grep(/secret create chef-secret-replaced/)).to be_empty
    end
  end
end
