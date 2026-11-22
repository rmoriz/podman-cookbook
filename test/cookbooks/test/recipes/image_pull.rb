# frozen_string_literal: true

podman_image 'pull-target' do
  repo 'busybox'
  action :pull
end
