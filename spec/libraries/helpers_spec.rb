# frozen_string_literal: true

require 'spec_helper'
require_relative '../../libraries/property_types'
require_relative '../../libraries/helpers_container'
require_relative '../../libraries/helpers_network'
require_relative '../../libraries/helpers_json'
require_relative '../../libraries/helpers_service'

describe PodmanCookbook::Helpers::Container do
  let(:harness) do
    Class.new do
      include PodmanCookbook::Helpers::Container
      attr_accessor :name

      def volumes_binds(value = nil)
        return @volumes_binds if value.nil?
        @volumes_binds = value
      end

      def repo(value = nil)
        return @repo if value.nil?
        @repo = value
      end

      def tag(value = nil)
        return @tag if value.nil?
        @tag = value
      end

      def exposed_ports(value = nil)
        return @exposed_ports if value.nil?
        @exposed_ports = value
      end

      def port_bindings(value = nil)
        return @port_bindings if value.nil?
        @port_bindings = value
      end
    end.new
  end

  it 'coerces string labels to a hash' do
    expect(harness.coerce_labels(['a=1', 'b=2'])).to eq('a' => '1', 'b' => '2')
  end

  it 'keeps hash labels' do
    expect(harness.coerce_labels('a' => '1')).to eq('a' => '1')
  end

  it 'sorts annotations and keeps a second equals sign in the value' do
    expect(harness.coerce_annotation(['b=2', 'a=1', 'k=a=b'])).to eq(['a=1', 'b=2', 'k=a=b'])
    expect(harness.coerce_annotation('k=')).to eq(['k='])
    expect(harness.coerce_annotation('')).to eq([])
    expect(harness.coerce_annotation(nil)).to eq([])
  end

  it 'rejects an annotation without a value separator' do
    expect { harness.coerce_annotation('bare') }.to raise_error(Chef::Exceptions::ValidationFailed)
  end

  it 'drops the annotations podman writes itself' do
    expect(
      harness.load_container_annotations(
        'Annotations' => {
          'io.podman.annotations.autoremove' => 'TRUE',
          'io.container.manager' => 'libpod',
          'org.opencontainers.image.stopSignal' => '15',
          'krun.cpus' => '2',
        }
      )
    ).to eq(['krun.cpus=2'])
  end

  it 'fills exposed ports and bindings from a port string' do
    harness.port '8080:80'
    expect(harness.exposed_ports).to eq('80/tcp' => {})
    expect(harness.port_bindings).to eq('80/tcp' => [{ 'HostIp' => '0.0.0.0', 'HostPort' => '8080' }])
  end

  it 'drops labels inherited from the image' do
    harness.define_singleton_method(:podman_inspect) do |kind, _name|
      kind == 'image' ? { 'Labels' => { 'from' => 'image' } } : nil
    end
    info = { 'Config' => { 'Image' => 'busybox', 'Labels' => { 'from' => 'image', 'mine' => '1' } } }
    expect(harness.load_container_labels(info)).to eq('mine' => '1')
  end

  it 'strips the container prefix from links' do
    harness.name = 'web'
    expect(harness.coerce_links(['/db:/web/db'])).to eq(['db:db'])
  end

  it 'parses byte strings' do
    expect(harness.to_bytes('64m')).to eq(64 * 1024 * 1024)
  end

  it 'converts cpus to nanocpus' do
    expect(harness.coerce_cpus(1.5)).to eq(1_500_000_000)
  end

  it 'coerces short port specs through the property coercions' do
    expect(harness.coerce_port_bindings('8080:80')).to eq(
      '80/tcp' => [{ 'HostIp' => '0.0.0.0', 'HostPort' => '8080' }]
    )
    expect(harness.coerce_exposed_ports('443')).to eq('443/tcp' => {})
  end

  it 'coerces a single port binding' do
    expect(harness.parse_port('8080:80')).to eq(
      [{ 'host_ip' => '0.0.0.0', 'host_port' => '8080', 'container_port' => '80/tcp' }]
    )
  end

  it 'treats an empty host address as the wildcard address' do
    binding = { '80/tcp' => [{ 'HostIp' => '', 'HostPort' => '8080' }] }
    expect(harness.normalize_port_bindings(binding)).to eq(
      '80/tcp' => [{ 'HostIp' => '0.0.0.0', 'HostPort' => '8080' }]
    )
    expect(harness.coerce_port_bindings(binding)).to eq(
      '80/tcp' => [{ 'HostIp' => '0.0.0.0', 'HostPort' => '8080' }]
    )
    # A concrete address has to survive.
    expect(harness.normalize_port_bindings('80/tcp' => [{ 'HostIp' => '127.0.0.1', 'HostPort' => '8080' }])).to eq(
      '80/tcp' => [{ 'HostIp' => '127.0.0.1', 'HostPort' => '8080' }]
    )
  end

  it 'expands port ranges' do
    expect(harness.parse_port('8000-8001:80-81')).to eq(
      [
        { 'host_ip' => '0.0.0.0', 'host_port' => '8000', 'container_port' => '80/tcp' },
        { 'host_ip' => '0.0.0.0', 'host_port' => '8001', 'container_port' => '81/tcp' },
      ]
    )
  end

  it 'builds exposed ports' do
    expect(harness.coerce_exposed_ports(['80', '53/udp'])).to eq('80/tcp' => {}, '53/udp' => {})
  end

  it 'separates binds from named volumes' do
    result = harness.coerce_volumes(['/host:/container:ro', 'named'])
    expect(result).to eq('named' => {})
    expect(harness.volumes_binds).to eq(['/host:/container:ro'])
  end

  it 'parses repo and tag from an image reference' do
    harness.name = 'x'
    harness.repo 'default'
    harness.tag 'latest'
    expect(harness.image('registry.example.com:5000/team/app:v1')).to eq('registry.example.com:5000/team/app:v1')
  end
end

describe PodmanCookbook::Helpers::Network do
  let(:harness) do
    Class.new do
      include PodmanCookbook::Helpers::Network
    end.new
  end

  it 'collapses a single element array' do
    expect(harness.coerce_string_or_array(['10.0.0.0/24'])).to eq('10.0.0.0/24')
  end

  it 'strips masks from a single gateway and keeps the string shape' do
    expect(harness.coerce_gateway(['10.0.0.1/24'])).to eq('10.0.0.1')
  end

  it 'keeps multiple gateways in an array' do
    expect(harness.coerce_gateway(%w(10.0.0.1/24 10.0.0.2/24))).to eq(%w(10.0.0.1 10.0.0.2))
  end

  it 'flattens auxiliary address hashes' do
    expect(harness.coerce_auxiliary_addresses([{ 'router' => '10.0.0.1' }])).to eq(['router=10.0.0.1'])
  end

  it 'turns dns_disabled into --disable-dns and keeps labels' do
    resource = Struct.new(
      :driver, :ipam_driver, :driver_opts, :subnet, :gateway, :ip_range,
      :internal, :enable_ipv6, :dns_disabled, :labels, :auxiliary_addresses
    ).new('bridge', nil, nil, ['10.0.0.0/24'], ['10.0.0.1'], nil, false, false, true,
          { 'owner' => 'chef' }, [])

    expect(harness.network_flags(resource)).to eq(
      ['--driver', 'bridge', '--subnet', '10.0.0.0/24', '--gateway', '10.0.0.1',
       '--disable-dns', '--label', 'owner=chef']
    )
  end
end

describe PodmanCookbook::Helpers::Json do
  let(:harness) do
    Class.new do
      include PodmanCookbook::Helpers::Json
      include PodmanCookbook::Helpers::Container
    end.new
  end

  let(:resource) do
    Struct.new(:dangling, :prune_until, :with_label, :without_label, :all).new(true, '24h', 'a=1', 'b=2', false)
  end

  it 'builds image prune filters' do
    expect(harness.image_prune_filters(resource)).to eq(
      ['dangling=true', 'until=24h', 'label=a=1', 'label!=b=2']
    )
  end

  it 'builds volume prune filters' do
    expect(harness.volume_prune_filters(resource)).to eq(['label=a=1', 'label!=b=2'])
  end
  it 'strips the Docker health check command prefix' do
    resource = double(
      health_check: { 'Test' => %w(CMD-SHELL curl -f http://localhost), 'Interval' => '30s', 'Retries' => 3 }
    )
    expect(harness.healthcheck_flags(resource)).to eq(
      ['--health-cmd', 'curl -f http://localhost', '--health-interval', '30s', '--health-retries', '3']
    )
  end

  it 'disables the health check for a NONE test' do
    expect(harness.healthcheck_flags(double(health_check: { 'Test' => ['NONE'] }))).to eq(['--no-healthcheck'])
  end

  it 'accepts symbol keys in health checks' do
    expect(harness.healthcheck_flags(double(health_check: { Test: %w(CMD pg_isready) }))).to eq(['--health-cmd', 'pg_isready'])
  end

  it 'passes restart retry counts through to the policy' do
    resource = double(restart_policy: 'on-failure', restart_maximum_retry_count: 3)
    expect(harness.restart_flags(resource)).to eq(['--restart', 'on-failure:3'])
  end
end

describe PodmanCookbook::Helpers::Service do
  let(:harness) do
    Class.new do
      include PodmanCookbook::Helpers::Service
    end.new
  end

  it 'names the default service podman' do
    allow(harness).to receive(:new_resource).and_return(double(name: 'default'))
    expect(harness.podman_name).to eq('podman')
  end

  it 'prefixes other service names' do
    allow(harness).to receive(:new_resource).and_return(double(name: 'test'))
    expect(harness.podman_name).to eq('podman-test')
  end

  it 'converts log_opts max-size into the byte count containers.conf wants' do
    resource = Struct.new(:log_opts).new(['max-size=10m'])

    expect(harness.containers_log_size_max(resource)).to eq(10 * 1024 * 1024)
  end

  it 'accepts a log_opts hash' do
    resource = double(log_opts: { 'max-size' => '512k' })

    expect(harness.containers_log_size_max(resource)).to eq(512 * 1024)
  end

  it 'keeps systemd_opts out of the systemctl command line' do
    resource = Struct.new(:user_mode, :systemd_opts).new(false, ['TimeoutSec=30'])

    expect(harness.podman_systemctl(resource)).to eq(['systemctl'])
  end

  it 'uses the user manager in user mode' do
    resource = Struct.new(:user_mode, :systemd_opts).new(true, [])

    expect(harness.podman_systemctl(resource)).to eq(['systemctl', '--user'])
  end

  it 'renders registries.conf v2 entries' do
    resource = Struct.new(:insecure_registry, :registry_mirror)
                     .new(['registry.local'], ['https://mirror.example.com'])
    output = harness.podman_registries_conf(resource)

    expect(output).to include("[[registry]]\nlocation = \"registry.local\"\ninsecure = true")
    expect(output).to include("[[registry.mirror]]\nlocation = \"mirror.example.com\"")
  end
end

describe PodmanCookbook::Helpers::Service do
  let(:harness) do
    Class.new do
      include PodmanCookbook::Helpers::Service
      attr_accessor :help_output

      def podman_name
        'podman-test'
      end

      def podman_shell_out(*)
        Struct.new(:stdout).new(help_output)
      end
    end.new
  end

  let(:resource) do
    Struct.new(:tls_server_cert, :tls_client_cert, :tls_server_key, :tls_client_key)
          .new(nil, '/etc/podman/client.crt', nil, '/etc/podman/client.key')
  end

  it 'falls back to the client pair as server pair' do
    harness.help_output = '      --tls-cert string   PEM file'
    expect(harness.podman_tls_cert(resource)).to eq('/etc/podman/client.crt')
    expect(harness.podman_tls_key(resource)).to eq('/etc/podman/client.key')
  end

  it 'drops the pair on a build without the TLS flags' do
    harness.help_output = '  -t, --time uint   Time until the service session expires'
    expect(harness.podman_tls_cert(resource)).to be_nil
    expect(harness.podman_tls_key(resource)).to be_nil
  end
end
