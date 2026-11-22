# frozen_string_literal: true

# The runner ships a static podman in /usr/bin and /usr/local/bin; drop both so
# the installer really has to install the packages.
# `file` resolves symlinks, so a dangling link (a local static install next to a
# package install) would raise; `rm -f` drops either.
%w(/usr/bin/podman /usr/local/bin/podman).each do |binary|
  execute "remove #{binary}" do
    command %W(rm -f #{binary})
    only_if "sh -c \"test -e #{binary} -o -L #{binary}\""
  end
end

podman_installation_script 'default' do
  action :create
end
