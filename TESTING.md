# Testing

Please refer to [the community cookbook documentation on testing](https://github.com/chef-cookbooks/community_cookbook_documentation/blob/main/TESTING.MD).

## Unit tests

The ChefSpec suite stubs the `podman` CLI, so no Podman installation is
required:

```sh
chef exec rspec
cookstyle
```

`spec/spec_helper.rb` records every `podman` command in `podman_commands` and
the environment of each call in `podman_environments`. Pass `stdout_for` when a
test needs inspect output, `failing_for` for a command that exits non-zero and
`exit_codes` for a specific exit code. `retried_for` lets the first matching
call fail and the later ones succeed, which exercises a retry.

## Kitchen

`kitchen.yml` uses the Vagrant driver for local runs. `kitchen.exec.yml` runs
the suites against the host through the Exec driver, which is what CI uses.

The installation suites need network access to the distribution package
repositories. The container suites pull `docker.io/library/busybox`.

CI runs the suites in groups that share setup, one runner per group, because a
runner costs more than the recipes of a group. Every group runs on an Ubuntu
runner, with Debian, Ubuntu or Rocky as the Kitchen platform, so the platform
data and the per-platform verifier controls change from group to group;
installation runs with all three. `kitchen test` also takes several instances at
once:

```sh
kitchen test image-build-ubuntu-2404 image-pull-ubuntu-2404
```
