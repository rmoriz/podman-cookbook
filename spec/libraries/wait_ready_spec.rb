# frozen_string_literal: true

require 'spec_helper'
require 'erb'

describe 'podman-wait-ready template' do
  let(:template) { ERB.new(File.read(File.expand_path('../../templates/default/default/podman-wait-ready.erb', __dir__))) }

  def render(**variables)
    context = Object.new
    { service_timeout: 5 }.merge(variables).each do |key, value|
      context.instance_variable_set("@#{key}", value)
    end
    template.result(context.instance_eval { binding })
  end

  it 'probes the socket with podman when no TLS is configured' do
    script = render(podman_bin: '/usr/bin/podman', podman_uri: 'unix:///run/podman/podman.sock')

    expect(script).to include('/usr/bin/podman --url=unix:///run/podman/podman.sock info')
    expect(script).not_to include('curl')
  end

  it 'hands over the client certificate when TLS is configured' do
    script = render(
      podman_socket: '/run/podman/podman.sock',
      podman_tls_cert: '/etc/podman/client.crt',
      podman_tls_key: '/etc/podman/client.key'
    )

    expect(script).to include('curl -sk --unix-socket /run/podman/podman.sock')
    expect(script).to include('--cert /etc/podman/client.crt --key /etc/podman/client.key')
  end
end
