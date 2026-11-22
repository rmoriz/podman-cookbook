# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'
require_relative '../../libraries/base'

describe PodmanCookbook::Helpers::Base do
  let(:resource) do
    Struct.new(:podman_bin, :host, :connection, :identity_path, :root, :data_root,
               :runroot, :storage_driver, :storage_opts, :cgroup_manager, :remote,
               :tls_verify, :cert_dir, :tls_ca_cert, :tls_client_cert,
               :tls_client_key, :run_as, :read_timeout) do
      def respond_to?(name, include_all = false)
        return true if self.class.members.include?(name)
        super
      end
    end.new('/usr/bin/podman', nil, nil, nil, nil, nil, nil, nil, nil, nil, false,
            nil, nil, nil, nil, nil, nil, 60)
  end

  let(:harness) do
    Struct.new(:new_resource) do
      include PodmanCookbook::Helpers::Base
      attr_reader :shelled

      def shell_out(command, **opts)
        @shelled = [command, opts]
        ::OpenStruct.new(exitstatus: 0, stdout: '[]', stderr: '', error?: false)
      end
    end.new(resource)
  end

  it 'gives a run_as process its own XDG directories' do
    allow(::Etc).to receive(:getpwnam).with('svc').and_return(double(uid: 4242, dir: '/home/svc'))
    resource.run_as = 'svc'

    expect(harness.podman_environment).to include(
      'HOME' => '/home/svc',
      'XDG_CONFIG_HOME' => '/home/svc/.config',
      'XDG_RUNTIME_DIR' => '/run/user/4242'
    )
  end

  it 'builds a command with the configured binary' do
    expect(harness.podman_command('ps')).to eq(%w(/usr/bin/podman ps))
  end

  it 'adds remote global flags' do
    resource.host = 'tcp://podman.example.com:8443'
    resource.connection = 'prod'
    resource.identity_path = '/etc/podman/id'
    resource.root = '/var/lib/containers'
    resource.runroot = '/run/containers'
    resource.storage_driver = 'overlay'
    resource.cgroup_manager = 'systemd'
    resource.remote = true

    expect(harness.podman_global_flags).to eq(
      [
        '--url=tcp://podman.example.com:8443',
        '--connection=prod',
        '--identity=/etc/podman/id',
        '--root=/var/lib/containers',
        '--runroot=/run/containers',
        '--storage-driver=overlay',
        '--cgroup-manager=systemd',
        '--remote',
      ]
    )
  end

  it 'maps data_root to the storage root and passes storage options' do
    resource.data_root = '/var/lib/containers'
    resource.storage_opts = ['size=10G']

    expect(harness.podman_global_flags).to include(
      '--root=/var/lib/containers',
      '--storage-opt=size=10G'
    )
  end

  it 'adds TLS flags for tcp hosts' do
    resource.host = 'tcp://podman.example.com:8443'
    resource.tls_verify = true
    resource.tls_ca_cert = '/etc/podman/ca.pem'
    resource.tls_client_cert = '/etc/podman/client.crt'
    resource.tls_client_key = '/etc/podman/client.key'
    resource.cert_dir = '/etc/podman'

    expect(harness.podman_global_flags).to eq(
      [
        '--url=tcp://podman.example.com:8443',
        '--tls-ca=/etc/podman/ca.pem',
        '--tls-cert=/etc/podman/client.crt',
        '--tls-key=/etc/podman/client.key',
      ]
    )
  end

  it 'quotes arguments that contain spaces' do
    harness.podman_shell_out('run', 'busybox', 'sh', '-c', 'echo hello')
    expect(harness.shelled.first).to include('echo\\ hello')
  end

  it 'builds an image identifier' do
    expect(harness.podman_image_identifier('busybox', 'latest')).to eq('busybox:latest')
    expect(harness.podman_image_identifier('busybox', 'sha256:abc')).to eq('busybox@sha256:abc')
  end
end
