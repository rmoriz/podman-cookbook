# frozen_string_literal: true

require 'spec_helper'

describe 'test::image_pull' do
  platform 'ubuntu', '24.04'
  step_into :podman_image

  def runner
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_image)
    )
  end

  it 'does not report a change when the digest stays the same' do
    stub_podman(stdout_for: { 'inspect' => 'sha256:same' })

    converge = runner.converge(described_recipe)

    expect(podman_commands).to include(a_string_matching(/podman pull busybox:latest/))
    expect(converge.find_resource(:podman_image, 'pull-target')).not_to be_updated_by_last_action
  end

  it 'reports a change when the pull replaces the image' do
    digests = %w(sha256:old sha256:new)

    [Chef::Resource, Chef::Provider].each do |klass|
      allow_any_instance_of(klass).to receive(:shell_out) do |_instance, *args, **_opts|
        output = args.join(' ').include?('inspect') ? digests.shift : ''
        PodmanShellResult.new(stdout: output, exitstatus: 0)
      end
      allow_any_instance_of(klass).to receive(:shell_out!) do |_instance, *args, **_opts|
        output = args.join(' ').include?('inspect') ? digests.shift : ''
        PodmanShellResult.new(stdout: output, exitstatus: 0).error!
      end
    end

    converge = runner.converge(described_recipe)

    expect(converge.find_resource(:podman_image, 'pull-target')).to be_updated_by_last_action
  end
end
