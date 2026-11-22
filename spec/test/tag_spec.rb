# frozen_string_literal: true

require 'spec_helper'

describe 'test::tag' do
  platform 'ubuntu', '24.04'
  step_into :podman_tag

  def converge
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_tag)
    ).converge(described_recipe)
  end

  it 'tags the source image with the target reference' do
    stub_podman(
      stdout_for: {
        'busybox:latest' => 'sha256:111',
        'chef-test' => 'sha256:222',
      }
    )

    expect(converge).to tag_podman_tag('busybox').with(
      to_repo: 'registry.example.com/busybox',
      to_tag: 'chef-test',
      force: true
    )
    expect(podman_commands).to include(a_string_matching(%r{podman tag busybox:latest registry\.example\.com/busybox:chef-test}))
  end

  it 'does not tag when the destination already points at the image' do
    stub_podman(stdout_for: { 'inspect' => 'sha256:111' })

    converge
    expect(podman_commands).not_to include(a_string_matching(/podman tag/))
  end
end
