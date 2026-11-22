# frozen_string_literal: true

require 'spec_helper'

describe 'test::container_env_file' do
  platform 'ubuntu', '24.04'
  step_into :podman_container

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_container)
    ).converge(described_recipe)
  end

  before do
    # ChefSpec does not converge the file resource, so stand in for it.
    File.write('/tmp/chef-container.env', "FROM_FILE=yes\n# a comment\nSECOND=1\n")
    stub_podman
    chef_run
  end

  it 'folds the env file entries into --env and skips blanks and comments' do
    create = podman_commands.find { |command| command.include?('create') }
    expect(create).to include('--env INLINE\=1')
    expect(create).to include('--env FROM_FILE\=yes')
    expect(create).to include('--env SECOND\=1')
    expect(create).not_to include('--env-file')
    expect(create).not_to include('a comment')
  end
end
