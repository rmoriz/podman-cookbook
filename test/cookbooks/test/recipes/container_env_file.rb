# frozen_string_literal: true

file '/tmp/chef-container.env' do
  content <<~ENVFILE
    FROM_FILE=yes
    # a comment
    SECOND=1
  ENVFILE
end

podman_container 'env-file' do
  repo 'busybox'
  env 'INLINE=1'
  env_file '/tmp/chef-container.env'
  action :create
end
