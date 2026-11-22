# frozen_string_literal: true

podman_installation_script 'script' do
  action :create
end

podman_installation_tarball 'tarball' do
  version '6.2.0'
  action :create
end

podman_service_manager_execute 'execute' do
  action :start
end

podman_container 'web' do
  repo 'busybox'
  command 'sleep 300'
  action :create
end

podman_generate_systemd 'web-service' do
  source 'web'
  type 'container'
  restart_policy 'always'
  # Extra units are written next to the generated one.
  files 'extra.service' => "[Unit]\nDescription=extra\n"
  action :create
end

podman_kube_play 'inline' do
  manifest_content <<~YAML
    apiVersion: v1
    kind: Pod
    metadata:
      name: inline
    spec:
      containers:
        - name: web
          image: docker.io/library/nginx:latest
  YAML
  action :play
end
