# frozen_string_literal: true

# Labels have no flag, so this manifest is inline; the resource folds them into
# the metadata. The remaining options are real `kube play` flags.
podman_kube_play 'options' do
  manifest_content <<~YAML
    apiVersion: v1
    kind: Pod
    metadata:
      name: options
    spec:
      containers:
        - name: web
          image: docker.io/library/nginx:latest
  YAML
  labels 'app' => 'web'
  annotation 'io.podman.annotations.userns=keep-id'
  publish_all true
  no_hosts true
  action :play
end
