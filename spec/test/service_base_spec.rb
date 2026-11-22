# frozen_string_literal: true

require 'spec_helper'

describe 'test::service_base' do
  platform 'ubuntu', '24.04'
  step_into :podman_service_manager, :podman_service_manager_systemd

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_service_manager podman_service_manager_systemd)
    ).converge(described_recipe)
  end

  before do
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv4.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_command('sh -c "/sbin/sysctl -q -n net.ipv6.conf.all.forwarding | grep ^1$"').and_return(true)
    stub_podman
  end

  def service_resource
    chef_run.resource_collection.all_resources.find { |entry| entry.name == 'base-instance' }
  end

  it 'passes the base settings to the manager alias' do
    chef_run
    resource = service_resource
    expect(resource.log_driver).to eq('journald')
    expect(resource.labels).to eq(['from=chef'])
    expect(resource.default_ulimit).to eq(['nofile=1024'])
    expect(resource.selinux_enabled).to be(false)
  end

  it 'registers alternative runtimes in containers.conf' do
    chef_run
    expect(service_resource.runtimes).to eq('crun' => ['/usr/bin/crun'], 'runsc' => ['/usr/bin/runsc'])
    expect(service_resource.runtime).to eq('crun')

    drop_in = chef_run.find_resource(
      :template,
      '/etc/containers/containers.conf.d/90-podman-podman-base-instance.conf'
    )
    expect(drop_in).not_to be_nil

    renderer = Object.new
    renderer.instance_variable_set(:@resource, drop_in.variables[:resource])
    renderer.instance_variable_set(:@log_size_max, drop_in.variables[:log_size_max])
    rendered = ERB.new(File.read('templates/default/service/containers.conf.erb')).result(
      renderer.instance_eval { binding }
    )
    expect(rendered).to include(%(runtime = "crun"))
    expect(rendered.lines.map(&:chomp)).to include(
      '[engine.runtimes]',
      'crun = ["/usr/bin/crun"]',
      'runsc = ["/usr/bin/runsc"]'
    )
  end

  it 'derives the pid file from the instance name' do
    chef_run
    expect(service_resource.pidfile).to eq('/run/podman-base-instance.pid')
  end

  it 'writes registries settings into a registries.conf drop-in' do
    chef_run
    drop_in = chef_run.find_resource(
      :file,
      '/etc/containers/registries.conf.d/90-podman-podman-base-instance.conf'
    )
    expect(drop_in).not_to be_nil
    expect(drop_in.content).to include('location = "registry.example.com"')
    expect(drop_in.content).to include('location = "mirror.example.com"')
  end

  it 'checks readiness against the socket it manages' do
    chef_run
    waiter = chef_run.find_resource(:template, '/usr/local/libexec/podman-base-instance-wait-ready')
    expect(waiter.variables[:podman_uri]).to eq('unix:///run/podman/podman.sock')
  end

  it 'creates the socket group the unit names' do
    chef_run
    expect(chef_run).to create_group('podman').with(system: true)
  end

  it 'creates the socket directory systemd binds into' do
    chef_run
    expect(chef_run).to create_directory('/run/podman').with(mode: '0755')
    expect(chef_run).to create_file('/etc/tmpfiles.d/podman-cookbook-podman-base-instance.conf').with(
      content: "d /run/podman 0755 root podman -\n"
    )
  end

  it 'writes the daemon log settings into a containers.conf drop-in' do
    chef_run
    drop_in = chef_run.find_resource(
      :template,
      '/etc/containers/containers.conf.d/90-podman-podman-base-instance.conf'
    )
    expect(drop_in).not_to be_nil
    expect(drop_in.variables[:resource].log_driver).to eq('journald')
    expect(drop_in.variables[:log_size_max]).to eq(10 * 1024 * 1024)
  end

  it 'converts max-size to the byte count containers.conf expects' do
    chef_run
    drop_in = chef_run.find_resource(
      :template,
      '/etc/containers/containers.conf.d/90-podman-podman-base-instance.conf'
    )
    renderer = Object.new
    renderer.extend(PodmanCookbook::Helpers::Service)
    renderer.render_template(drop_in) if renderer.respond_to?(:render_template)

    max = renderer.containers_log_size_max(drop_in.variables[:resource])
    expect(max).to eq(10 * 1024 * 1024)
  end
end
