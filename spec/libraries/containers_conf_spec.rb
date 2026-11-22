# frozen_string_literal: true

require 'spec_helper'
require 'erb'
require 'ostruct'
require_relative '../../libraries/helpers_service'

describe 'containers.conf template' do
  let(:template) { ERB.new(File.read(File.expand_path('../../templates/default/service/containers.conf.erb', __dir__))) }

  let(:resource) do
    OpenStruct.new(
      storage_driver: 'overlay', data_root: '/var/lib/containers', storage_opts: ['size=10G'],
      dns: ['1.1.1.1'], dns_search: ['example.com'], log_driver: 'journald', log_opts: ['max-size=10m'],
      env_vars: { 'FOO' => 'bar' }, default_ulimit: ['nofile=1024:2048'], bridge: 'podman0',
      userns_remap: 'keep-id', http_proxy: 'http://proxy:3128', https_proxy: nil, no_proxy: 'localhost',
      tmpdir: '/var/tmp', cgroup_manager: 'systemd', runtime: 'crun', group: 'podman', service_timeout: 20,
      registry_mirror: ['https://mirror.example.com'], insecure_registry: ['registry.local'],
      default_ip_address_pool: nil, fixed_cidr: nil, bip: '10.88.0.1/16', iptables: false, ip6tables: true
    )
  end

  def render(resource)
    renderer = Object.new
    renderer.extend(PodmanCookbook::Helpers::Service)
    renderer.instance_variable_set(:@resource, resource)
    renderer.instance_variable_set(:@log_size_max, renderer.containers_log_size_max(resource))
    template.result(renderer.instance_eval { binding })
  end

  it 'renders the options containers.conf knows' do
    output = render(resource)

    expect(output).to include('dns_servers = ["1.1.1.1"]')
    expect(output).to include('log_size_max = 10485760')
    expect(output).to include('env = ["FOO=bar"]')
    expect(output).to include('default_ulimits = ["nofile=1024:2048"]')
    expect(output).to include('netns = "podman0"')
    expect(output).to include('userns = "keep-id"')
    expect(output).to include('"HTTP_PROXY=http://proxy:3128"')
    expect(output).to include('"TMPDIR=/var/tmp"')
    expect(output).to include('default_subnet = "10.88.0.1/16"')
    expect(output).to include('firewall_driver = "none"')
  end

  it 'omits sections for unset options' do
    output = render(OpenStruct.new(dns: nil, iptables: true, ip6tables: true))

    expect(output).not_to include('[storage]')
    expect(output).not_to include('[registries]')
    expect(output).not_to include('[containers]')
    expect(output).not_to include('[network]')
    expect(output).not_to include('[engine]')
  end

  it 'maps selinux_enabled onto the label switch' do
    output = render(OpenStruct.new(selinux_enabled: false))

    expect(output).to include('label = false')
  end

  it 'maps a max-size log option only once' do
    output = render(OpenStruct.new(log_opts: 'max-size=5m'))
    expect(output.scan('log_size_max').length).to eq(1)
  end
end
