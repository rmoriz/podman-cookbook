#!/bin/sh
# Install Podman and its supporting tools from the distribution repositories.
set -eu

BASE="podman netavark aardvark-dns"

. /etc/os-release

case "${ID} ${ID_LIKE:-}" in
  *debian*|*ubuntu*)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    # shellcheck disable=SC2086
    # `--reinstall` also restores package files that were removed (a static
    # Podman symlink at the package path, for example).
    apt-get install -y --reinstall $BASE podman-docker containernetworking-plugins uidmap
    ;;
  *suse*)
    # shellcheck disable=SC2086
    zypper --non-interactive install --force-resolution $BASE podman-docker shadow
    ;;
  amzn*|*amazon*)
    # Podman lives in the Supplementary Packages repository on Amazon Linux.
    dnf install -y spal-release
    # shellcheck disable=SC2086
    dnf install -y $BASE podman-docker shadow-utils
    ;;
  *rhel*|*fedora*|*centos*)
    CNI="containernetworking-plugins"
    # EL10 and later ship netavark only.
    if [ "${ID}" != "fedora" ] && [ "${VERSION_ID%%.*}" -ge 10 ]; then
      CNI=""
    fi
    # shellcheck disable=SC2086
    dnf install -y $BASE podman-docker $CNI shadow-utils
    ;;
  *)
    echo "Unsupported distribution: ${ID:-unknown}" >&2
    exit 1
    ;;
esac
