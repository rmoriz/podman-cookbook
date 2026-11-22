# `su` keeps the caller's environment, and the runner exports XDG paths inside
# root's home, which the unprivileged user cannot read. Set the user's own
# directories the same way the resource does.
machine_env = %w(
  HOME=/home/podmanmachine
  XDG_CONFIG_HOME=/home/podmanmachine/.config
  XDG_DATA_HOME=/home/podmanmachine/.local/share
  XDG_CACHE_HOME=/home/podmanmachine/.cache
).join(' ')

control 'machine-exists' do
  impact 1.0
  title 'The machine was initialised'

  describe command("su -s /bin/sh podmanmachine -c '#{machine_env} /usr/bin/podman machine inspect ci'") do
    its('exit_status') { should eq 0 }
    its('stderr') { should be_empty }
  end
end
