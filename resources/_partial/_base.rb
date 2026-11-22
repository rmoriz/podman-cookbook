# frozen_string_literal: true

require 'shellwords'

include PodmanCookbook::Helpers::Base

property :podman_bin, String, default: '/usr/bin/podman', desired_state: false
alias_method :docker_bin, :podman_bin

property :host, [String, Array, nil],
         default: lazy { ENV['CONTAINER_HOST'] || ENV['DOCKER_HOST'] },
         coerce: proc { |value| value.nil? ? nil : Array(value) },
         desired_state: false

property :connection, String, desired_state: false
property :identity_path, String, desired_state: false
property :root, String, desired_state: false
property :runroot, String, desired_state: false
property :cgroup_manager, String, desired_state: false
property :remote, [true, false], default: false, desired_state: false
property :run_as, String, desired_state: false

property :api_retries, Integer, default: 3, desired_state: false
# A ceiling, not an expected duration: on loaded hosts Podman can take a while
# to report back, especially while a container exits and is cleaned up.
property :read_timeout, Integer, default: 180, desired_state: false
property :write_timeout, Integer, desired_state: false
property :running_wait_time, Integer, default: 20, desired_state: false

property :tls, [TrueClass, FalseClass, nil], default: lazy { ENV['CONTAINER_TLS'] }, desired_state: false
property :tls_verify, [TrueClass, FalseClass, nil], default: lazy { ENV['CONTAINER_TLS_VERIFY'] }, desired_state: false
property :cert_dir, [String, nil], default: lazy { ENV['CONTAINER_CERT_DIR'] }, desired_state: false
property :tls_ca_cert, [String, nil], desired_state: false
property :tls_server_cert, String, desired_state: false
property :tls_server_key, String, desired_state: false
property :tls_client_cert, [String, nil], desired_state: false
property :tls_client_key, [String, nil], desired_state: false

alias_method :tlscacert, :tls_ca_cert
alias_method :tlscert, :tls_server_cert
alias_method :tlskey, :tls_server_key
alias_method :tlsverify, :tls_verify

action_class do
  include PodmanCookbook::Helpers::Base

  def parse_registry_host(value)
    first_part = value.sub(%r{https?://}, '').split('/').first
    return first_part if first_part.include?('.') || first_part.include?(':') || first_part == 'localhost'
    'docker.io'
  end
end
