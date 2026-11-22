# frozen_string_literal: true

module PodmanCookbook
  module Helpers
    module Network
      def coerce_auxiliary_addresses(value)
        return value if value.nil?
        return value.map { |key, val| "#{key}=#{val}" } if value.is_a?(Hash)

        Array(value).flat_map do |entry|
          entry.is_a?(Hash) ? entry.map { |key, val| "#{key}=#{val}" } : Array(entry)
        end.map(&:to_s)
      end

      def coerce_network_labels(value)
        case value
        when Hash, nil
          value
        else
          Array(value).each_with_object({}) do |label, memo|
            key, _, rest = label.partition('=')
            memo[key] = rest
          end
        end
      end

      # A single gateway is normalised to a String and multiple ones keep the
      # Array shape, so an inspect result compares equal to either spelling.
      def coerce_gateway(value)
        return value if value.nil?
        list = Array(value).map { |entry| entry.to_s.split('/').first }
        list.length == 1 ? list.first : list
      end

      def coerce_string_or_array(value)
        value.is_a?(Array) && value.length == 1 ? value.first : value
      end

      def network_flags(resource)
        flags = []
        flags.push('--driver', resource.driver) if resource.driver
        flags.push('--ipam-driver', resource.ipam_driver) if resource.ipam_driver
        resource.driver_opts.each { |key, value| flags.push('--opt', "#{key}=#{value}") } if resource.driver_opts
        Array(resource.subnet).each { |subnet| flags.push('--subnet', subnet) }
        Array(resource.gateway).each { |gateway| flags.push('--gateway', gateway) }
        Array(resource.ip_range).each { |range| flags.push('--ip-range', range) }
        flags << '--internal' if resource.internal
        flags << '--ipv6' if resource.enable_ipv6
        flags << '--disable-dns' if resource.dns_disabled
        (resource.labels || {}).each { |key, value| flags.push('--label', "#{key}=#{value}") }
        # Podman has no `--aux-address` flag, so the addresses are only kept as
        # labels for drift detection (inspect does not report them either).
        Array(resource.auxiliary_addresses).each_with_index do |address, index|
          flags.push('--label', "aux_address_#{index}=#{address}")
        end
        flags
      end

      # Podman below 5 does not list the attached containers in `network
      # inspect`, so the container side is authoritative.
      def container_networks(container)
        info = podman_inspect('container', container)
        (info && info.dig('NetworkSettings', 'Networks')) || {}
      rescue StandardError
        {}
      end
    end
  end
end
