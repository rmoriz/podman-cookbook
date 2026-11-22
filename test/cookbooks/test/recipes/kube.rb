# frozen_string_literal: true

podman_image 'busybox' do
  action :pull
end

podman_container 'kube-source' do
  repo 'busybox'
  command 'sleep 300'
  labels('app' => 'chef-test')
  action :run
end

podman_kube_generate 'kube-source' do
  destination '/tmp/kube-source.yaml'
  action :generate
end

podman_kube_play '/tmp/kube-source.yaml' do
  action :play
end

podman_kube_play '/tmp/kube-source.yaml' do
  action :teardown
end

podman_secret 'inline-secret' do
  value 'hunter2'
  action :create
end

podman_kube_play 'inline-manifest' do
  manifest_content <<~YAML
    apiVersion: v1
    kind: Pod
    metadata:
      name: inline
    spec:
      containers:
        - name: web
          image: busybox
  YAML
  namespace 'chef-test'
  env 'GREETING=hello'
  secrets ['inline-secret']
  action :play
end
