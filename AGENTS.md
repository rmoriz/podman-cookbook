# AGENTS.md

## Cookbook Purpose

Installs Podman and provides `podman_*` resources for containers, images,
networks, volumes, pods, kube workloads, secrets and systemd units. It is the
Podman counterpart of the Sous Chefs Docker cookbook.

## Agent Findings

* Drive Podman through its CLI. `docker-api` assumes a Docker daemon and misses
  pods, kube, quadlet, secrets and rootless sockets.
* Podman's Docker-compatible API marks `/plugins` unsupported, so there is no
  plugin resource; everything goes through the CLI.
* Packages come from the distribution repositories; no third-party repository
  is configured.
* There are no Swarm resources. Podman has no native Swarm mode, and the cookbook
  no longer wraps the `docker` CLI for it; pods and kube manifests cover the same
  ground.

## Supported Platforms

Only the current release and its predecessor are supported.

* AlmaLinux 9/10
* Amazon Linux 2023
* CentOS Stream 9/10
* Debian 12/13
* Fedora 42/43
* openSUSE Leap 15.6/16.0, Tumbleweed
* Oracle Linux 9/10
* Red Hat Enterprise Linux 9/10
* Rocky Linux 9/10
* Ubuntu 26.04/26.10

## Requirements

* Chef Infra Client 18.0 or later
* systemd for the systemd service manager

## Rootless

Set `run_as` on resources or `user` on `podman_service_manager_systemd` with
`user_mode true`. Rootless operation requires subuid/subgid mappings and
`uidmap`/`shadow-utils`, which the package installer installs.
