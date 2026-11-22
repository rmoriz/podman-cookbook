# frozen_string_literal: true

require 'spec_helper'

describe 'test::install_package' do
  platform 'opensuse', '15.2'
  step_into :podman_installation_package

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'opensuse',
      version: '15.2',
      step_into: %w(podman_installation_package)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'allows the zypper vendor change' do
    expect(chef_run).to install_package('podman packages').with(
      options: ['--allow-vendor-change']
    )
  end

  it 'installs the SUSE shadow package and skips the missing CNI plugins' do
    expect(chef_run).to install_package('podman packages').with(
      package_name: satisfy do |packages|
        packages.include?('shadow') &&
          !packages.include?('shadow-utils') &&
          !packages.include?('containernetworking-plugins')
      end
    )
  end

  it 'writes the nodocker marker' do
    expect(chef_run).to create_file('/etc/containers/nodocker').with(mode: '0644')
  end

  it 'does not manage a repository' do
    expect(chef_run).not_to add_zypper_repository('home-alvistack')
  end
end

describe 'test::install_package' do
  platform 'amazon', '2023'
  step_into :podman_installation_package

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'amazon', # rubocop:disable Chef/Deprecations/DeprecatedChefSpecPlatform
      version: '2023',
      step_into: %w(podman_installation_package)
    ).converge(described_recipe)
  end

  before { stub_podman }

  it 'enables the Amazon repository first' do
    expect(chef_run).to install_package('spal-release')
  end

  it 'installs only the packages Amazon Linux carries' do
    expect(chef_run).to install_package('podman packages').with(
      package_name: %w(podman netavark aardvark-dns podman-docker shadow-utils)
    )
  end
end
