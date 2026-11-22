# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_image
provides :podman_image

include PodmanCookbook::Helpers::Container

property :read_timeout, Integer, default: 120, desired_state: false
property :destination, String
property :force, [true, false], default: false, desired_state: false
property :nocache, [true, false], default: false
property :noprune, [true, false], default: false
property :repo, String, name_property: true
property :rm, [true, false], default: true
property :source, String
property :tag, String, default: 'latest'
property :buildargs, [String, Hash], coerce: proc { |v| v.is_a?(String) ? v : coerce_buildargs(v) }

alias_method :image, :repo
alias_method :image_name, :repo
alias_method :no_cache, :nocache
alias_method :no_prune, :noprune

action :pull do
  # Report a change only when the pull actually replaced the image, so an
  # already current image does not look like drift on every run.
  before = image_digest
  pull_image
  converge_by("pull image #{image_identifier}") {} if image_digest != before
end

action :build do
  raise 'Please set the source property for podman_image builds' unless new_resource.source
  converge_by("build image #{image_identifier}") do
    build_image
  end
end

action :build_if_missing do
  return if image_exist?
  action_build
end

action :import do
  raise 'Please set the source property for podman_image imports' unless new_resource.source
  return if image_exist?
  converge_by("import image #{image_identifier}") do
    podman_execute!('import', new_resource.source, image_identifier)
  end
end

action :pull_if_missing do
  return if image_exist?
  action_pull
end

action :push do
  converge_by("push image #{image_identifier}") do
    podman_execute!('push', image_identifier)
  end
end

action :remove do
  return unless image_exist?
  converge_by("remove image #{image_identifier}") do
    args = ['rmi']
    args << '--force' if new_resource.force
    args << image_identifier
    podman_execute!(*args)
  end
end

action :save do
  raise 'Please set the destination property for podman_image save' unless new_resource.destination

  # `podman save --output` does not create missing directories.
  destination_dir = ::File.dirname(new_resource.destination)
  if ::File.absolute_path(destination_dir) == destination_dir
    directory destination_dir do
      recursive true
    end
  end

  converge_by("save image #{image_identifier}") do
    # `podman save` cannot modify an existing docker-archive in place and the
    # flag has no --force, so it writes next to the target and moves over it.
    temporary = "#{new_resource.destination}.tmp"
    podman_execute!('save', '--output', temporary, image_identifier)
    ::FileUtils.mv(temporary, new_resource.destination)
  end
end

action :load do
  raise 'Please set the source property for podman_image loads' unless new_resource.source
  return if image_exist?
  converge_by("load image from #{new_resource.source}") do
    podman_execute!('load', '--input', new_resource.source)
  end
end

action_class do
  include PodmanCookbook::Helpers::Container

  def image_identifier
    podman_image_identifier(new_resource.repo, new_resource.tag)
  end

  def image_exist?
    podman_image_exists?(image_identifier)
  end

  def image_digest
    return unless image_exist?
    podman_shell_out('image', 'inspect', '--format', '{{.Digest}}', image_identifier).stdout.strip
  end

  def pull_image
    with_retries { podman_execute!('pull', image_identifier) }
  end

  def build_image
    args = ['build', '--tag', image_identifier]
    args << '--no-cache' if new_resource.nocache
    # Docker's `noprune` means "keep intermediate images"; with `podman build`
    # that is `--rm=false`, not `--layers` (which only controls the cache).
    args << if new_resource.noprune || !new_resource.rm
              '--rm=false'
            else
              '--force-rm'
            end
    Array(new_resource.buildargs).each { |arg| args.push('--build-arg', arg) }
    # A directory or a tar archive is the build context itself, a plain file is
    # a Dockerfile that needs `--file` plus its directory as context.
    if ::File.directory?(new_resource.source) || ::File.extname(new_resource.source) == '.tar'
      args << new_resource.source
    else
      args.push('--file', new_resource.source, ::File.dirname(new_resource.source))
    end
    with_retries { podman_execute!(*args) }
  end
end
