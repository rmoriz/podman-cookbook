# frozen_string_literal: true

module PodmanCookbook
  module Helpers
    module Json
      def image_prune_filters(resource)
        filters = []
        filters << "dangling=#{resource.dangling}" unless resource.dangling.nil?
        filters << "until=#{resource.prune_until}" if resource.prune_until
        filters << "label=#{resource.with_label}" if resource.with_label
        filters << "label!=#{resource.without_label}" if resource.without_label
        filters
      end

      def volume_prune_filters(resource)
        filters = []
        filters << "label=#{resource.with_label}" if resource.with_label
        filters << "label!=#{resource.without_label}" if resource.without_label
        filters
      end
    end
  end
end
