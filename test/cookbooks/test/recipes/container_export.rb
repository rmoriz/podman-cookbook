# frozen_string_literal: true

podman_container 'exporter' do
  repo 'busybox'
  outfile '/tmp/exports/exporter.tar'
  action :export
end
