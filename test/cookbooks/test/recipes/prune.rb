# frozen_string_literal: true

podman_image_prune 'prune dangling images' do
  dangling true
  action :prune
end

podman_volume_prune 'prune volumes' do
  with_label 'chef=true'
  action :prune
end

podman_image_prune 'prune old labelled images' do
  dangling false
  prune_until '24h'
  with_label 'chef=true'
  without_label 'keep=true'
  action :prune
end

podman_image_prune 'prune with a timeout' do
  read_timeout 30
  action :prune
end

podman_volume_prune 'prune all volumes' do
  all true
  read_timeout 15
  action :prune
end
