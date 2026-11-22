# frozen_string_literal: true

file '/tmp/Dockerfile.build' do
  content <<~DOCKERFILE
    FROM busybox
    RUN echo built
  DOCKERFILE
end

podman_image 'chef-build' do
  source '/tmp/Dockerfile.build'
  noprune true
  action :build
end
