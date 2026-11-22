# frozen_string_literal: true

module PodmanCookbook
  module Helpers
    # Package names used by the installation resources. Podman comes from the
    # distribution repositories, so only the per-family extras differ.
    module Install
      BASE_PACKAGES = %w(podman netavark aardvark-dns).freeze

      def podman_default_packages(node = self.node)
        extra = case node['platform_family']
                when 'debian' then %w(podman-docker containernetworking-plugins uidmap)
                when 'suse' then %w(podman-docker shadow)
                when 'amazon' then %w(podman-docker shadow-utils)
                else
                  packages = %w(podman-docker shadow-utils)
                  # EL10 and later ship netavark only.
                  packages << 'containernetworking-plugins' unless el10?
                  packages
                end

        [*BASE_PACKAGES, *extra]
      end

      def el10?(node = self.node)
        node['platform_family'] == 'rhel' && node['platform_version'].to_i >= 10
      end
    end
  end
end
