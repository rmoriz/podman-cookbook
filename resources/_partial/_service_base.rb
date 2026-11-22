# frozen_string_literal: true

include PodmanCookbook::Helpers::Service

# The daemon log settings are written into containers.conf and the pid file is
# used by the execute service manager to find a running daemon.
property :pidfile, String, default: lazy { "/run/#{podman_name}.pid" }

property :env_vars, Hash, default: {}
property :auto_restart, [true, false], default: true

property :instance, String, name_property: true, desired_state: false
property :api_cors_header, String
property :bridge, String
property :bip, String
property :cluster_store, String
property :cluster_advertise, String
property :cluster_store_opts, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :daemon, [true, false], default: true
property :data_root, String
property :debug, [true, false], default: false
property :dns, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :dns_search, Array
property :exec_driver, ['native', 'lxc', nil]
property :exec_opts, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :fixed_cidr, String
property :fixed_cidr_v6, String
property :group, String, default: 'podman'
property :icc, [true, false]
property :insecure_registry, [Array, String, nil], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :ip, String
property :ip_forward, [true, false]
property :ip_masq, [true, false]
property :iptables, [true, false]
property :ip6tables, [true, false]
property :ipv6, [true, false]
property :default_ip_address_pool, String
property :log_level, %w(debug info warn error fatal)
property :labels, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :registry_mirror, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :storage_driver, String
property :storage_opts, Array
property :mount_flags, String
property :mtu, String
property :misc_opts, String
property :systemd_opts, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :systemd_socket_opts, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :http_proxy, String
property :https_proxy, String
property :no_proxy, String
property :tmpdir, String
property :logfile, String, default: '/var/log/podman.log'
property :service_timeout, Integer, default: 20
property :default_ulimit, [String, Array], coerce: proc { |value| value.nil? ? nil : Array(value) }
property :userland_proxy, [true, false]
property :disable_legacy_registry, [true, false]
property :userns_remap, String
property :user_mode, [true, false], default: false
property :user, String

# Accepted for docker_service compatibility where Podman has an equivalent.
property :runtime, String
# Search paths per OCI runtime name, rendered into `[engine.runtimes]`. Podman
# needs the entry before a name may be used in `runtime`; the usual names are
# `runsc` (gVisor) and `crun-wasm`, see
# documentation/alternative-runtimes.md.
property :runtimes, Hash, default: {},
                          coerce: proc { |value| value.nil? ? {} : value.transform_values { |paths| Array(paths) } },
                          description: 'Runtime name to list of executable paths'
property :selinux_enabled, [true, false]
property :ipv4_forward, [true, false], default: true
property :ipv6_forward, [true, false], default: true
property :live_restore, [true, false], default: false

alias_method :label, :labels
alias_method :run_group, :group
alias_method :graph, :data_root

action_class do
  include PodmanCookbook::Helpers::Service

  def containers_conf_dir
    podman_conf_dir
  end

  def containers_conf_file
    ::File.join(containers_conf_dir, "90-podman-#{podman_name}.conf")
  end

  def daemon_env
    env = {}
    env['HTTP_PROXY'] = new_resource.http_proxy if new_resource.http_proxy
    env['HTTPS_PROXY'] = new_resource.https_proxy if new_resource.https_proxy
    env['NO_PROXY'] = new_resource.no_proxy if new_resource.no_proxy
    env['TMPDIR'] = new_resource.tmpdir if new_resource.tmpdir
    new_resource.env_vars.each { |key, value| env[key] = value }
    env
  end

  def podman_wait_ready
    "/usr/local/libexec/#{podman_name}-wait-ready"
  end

  def enable_forwarding
    execute 'enable net.ipv4.conf.all.forwarding' do
      command '/sbin/sysctl -w net.ipv4.conf.all.forwarding=1'
      not_if 'sh -c "/sbin/sysctl -q -n net.ipv4.conf.all.forwarding | grep ^1$"'
    end

    execute 'enable net.ipv6.conf.all.forwarding' do
      command '/sbin/sysctl -w net.ipv6.conf.all.forwarding=1'
      not_if 'sh -c "/sbin/sysctl -q -n net.ipv6.conf.all.forwarding | grep ^1$"'
      only_if { node['kernel']['machine'] != 's390x' }
    end
  end
end
