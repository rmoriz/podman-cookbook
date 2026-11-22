# frozen_string_literal: true

unified_mode true
use '_partial/_base'
use '_partial/_logging'
use '_partial/_service_base'

# Shared base for the service managers. Podman has no daemon config file, so
# the daemon settings are written into a containers.conf drop-in; the managers
# differ only in how they keep the daemon running.
resource_name :podman_service_base
provides :podman_service_base
