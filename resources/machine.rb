# frozen_string_literal: true

unified_mode true
use '_partial/_base'

resource_name :podman_machine
provides :podman_machine

# Podman machines are the Linux VMs used by Podman Desktop and by `podman`
# on macOS and Windows. They are Podman-only.
property :machine_name, String, name_property: true
property :cpus, Integer
property :memory, Integer
property :disk_size, Integer
property :image, String
property :provider_type, String
property :rootful, [true, false], default: false
property :user_mode_networking, [true, false], default: false
property :volume, [String, Array], default: [], coerce: proc { |v| Array(v) }
property :timezone, String
property :playbook, String
property :now, [true, false], default: true
# A machine boots a VM and shuts it down gracefully; that is much slower than a
# container command, especially without hardware virtualization.
property :read_timeout, Integer, default: 900
# Podman gives up on a boot that takes too long and then leaves the VM running
# but unreachable, so the machine has to be restarted on hosts without
# hardware virtualization, where a boot needs many minutes. Each attempt is one
# more boot from the previously booted disk, so it gets further than the one
# before.
property :start_attempts, Integer, default: 10, desired_state: false

action :init do
  return if machine_info

  converge_by "initializing podman machine #{new_resource.machine_name}" do
    args = %w(machine init)
    args.push('--cpus', new_resource.cpus.to_s) if new_resource.cpus
    args.push('--memory', new_resource.memory.to_s) if new_resource.memory
    args.push('--disk-size', new_resource.disk_size.to_s) if new_resource.disk_size
    args.push('--image', new_resource.image) if new_resource.image
    args.push('--provider', new_resource.provider_type) if new_resource.provider_type
    args << '--rootful' if new_resource.rootful
    args << '--user-mode-networking' if new_resource.user_mode_networking
    new_resource.volume.each { |v| args.push('--volume', v) }
    args.push('--timezone', new_resource.timezone) if new_resource.timezone
    args.push('--playbook', new_resource.playbook) if new_resource.playbook
    # `--now` would boot before the ignition can be repaired, so the boot is
    # started below instead.
    args << new_resource.machine_name
    podman_execute!(*args)
    tighten_ssh_key
    repair_ignition
    boot_machine('machine', 'start', new_resource.machine_name) if new_resource.now
  end
end

action :start do
  return if machine_running?

  converge_by "starting podman machine #{new_resource.machine_name}" do
    # A machine someone else initialised may carry the unfixed ignition.
    tighten_ssh_key
    repair_ignition
    boot_machine('machine', 'start', new_resource.machine_name)
  end
end

action :stop do
  return unless machine_running?

  converge_by "stopping podman machine #{new_resource.machine_name}" do
    podman_execute!('machine', 'stop', new_resource.machine_name)
  end
end

action :remove do
  return unless machine_info

  converge_by "removing podman machine #{new_resource.machine_name}" do
    podman_execute!('machine', 'rm', '--force', new_resource.machine_name)
  end
end

action_class do
  include PodmanCookbook::Helpers::Service

  def machine_info
    # `machine inspect` prints JSON on its own; the shared inspect helper's
    # `--format` is not accepted by every Podman version.
    result = podman_shell_out('machine', 'inspect', new_resource.machine_name)
    return unless result.exitstatus.zero?

    data = JSON.parse(result.stdout)
    data.is_a?(Array) ? data.first : data
  rescue JSON::ParserError
    nil
  end

  # Depending on the Podman version the state is a plain string or a nested
  # object, so both shapes are accepted.
  def machine_state
    state = machine_info&.fetch('State', nil)
    state = state['State'] if state.is_a?(Hash)
    state.to_s
  end

  # Podman 4 reports an empty state for a machine whose VM is up but whose SSH
  # never answered, so the VM process counts as well: a leftover qemu keeps
  # `machine start` from booting again.
  def machine_running?
    return true if machine_state.casecmp?('running')

    !machine_vm_pid.nil?
  end

  def machine_vm_pid
    path = ::File.join(machine_runtime_dir, 'podman', "#{new_resource.machine_name}_vm.pid")
    pid = ::File.read(path).to_i
    return if pid.zero?

    Process.kill(0, pid)
    pid
  rescue Errno::ENOENT, Errno::ESRCH, Errno::EPERM
    nil
  end

  def machine_runtime_dir
    uid = new_resource.run_as ? ::Etc.getpwnam(new_resource.run_as).uid : 0
    "/run/user/#{uid}"
  rescue ArgumentError
    Chef::Log.warn("podman: run_as user #{new_resource.run_as} does not exist")
    '/run/user/0'
  end

  def machine_config_dir
    config = machine_info&.dig('ConfigPath', 'Path')
    return ::File.dirname(config) if config

    ::File.join(podman_user_home(new_resource.run_as), '.config/containers/podman/machine/qemu')
  end

  # The ignition file Podman 4 writes needs two fixes before the first boot of a
  # current Fedora CoreOS image, so it is repaired between `machine init` and
  # the boot:
  #
  # * `/etc/subuid` and `/etc/subgid` are data URLs without a trailing newline,
  #   and the Podman inside the guest rejects such a file with `Non-text file`.
  #   The boot then fails although the VM is up.
  # * `ready.service`, which prints the line `machine start` waits for, requires
  #   `/dev/virtio-ports/vport1p1`. Kernels since 6.x name the port after its
  #   tag, so only `/dev/vport1p1` and a tag-named link exist and the unit never
  #   starts. `machine start` then waits forever.
  #
  # Both repairs are idempotent and stay valid for every later boot.
  def repair_ignition
    path = ::File.join(machine_config_dir, "#{new_resource.machine_name}.ign")
    return unless ::File.exist?(path)

    document = JSON.parse(::File.read(path))
    changed = repair_ignition_subids(document)
    changed = repair_ignition_ready_unit(document) || changed
    return unless changed

    ::File.write(path, JSON.pretty_generate(document))
    Chef::Log.info("#{new_resource.machine_name}: repaired the ignition file")
  rescue JSON::ParserError => e
    Chef::Log.warn("#{new_resource.machine_name}: could not repair the ignition file: #{e.message}")
  end

  def repair_ignition_subids(document)
    changed = false
    Array(document.dig('storage', 'files')).each do |file|
      next unless %w(/etc/subuid /etc/subgid).include?(file['path'])

      source = file.dig('contents', 'source').to_s
      next if source.end_with?('%0A', '%0a')

      file['contents']['source'] = "#{source}%0A"
      changed = true
    end
    changed
  end

  def repair_ignition_ready_unit(document)
    changed = false
    Array(document.dig('systemd', 'units')).each do |unit|
      next unless unit['name'] == 'ready.service'

      contents = unit['contents'].to_s
      next unless contents.include?('dev-virtio\\\\x2dports-vport1p1.device')

      unit['contents'] = contents.gsub('dev-virtio\\\\x2dports-vport1p1.device', 'dev-vport1p1.device')
      changed = true
    end
    changed
  end

  # The identity file has to stay private, or `ssh` refuses it with
  # `UNPROTECTED PRIVATE KEY FILE` and the boot wait fails on that alone. Some
  # installs leave it with the umask-derived mode, so it is set explicitly.
  def tighten_ssh_key
    identity = machine_info&.dig('SSHConfig', 'IdentityPath')
    return unless identity && ::File.exist?(identity)
    return if (::File.stat(identity).mode & 0o777) == 0o600

    ::File.chmod(0o600, identity)
  rescue SystemCallError => e
    Chef::Log.warn("#{new_resource.machine_name}: could not tighten the identity file: #{e.message}")
  end

  # Podman 4 writes `/etc/subuid` and `/etc/subgid` into the guest without a
  # trailing newline, and the Podman inside the current Fedora CoreOS image
  # rejects a file that does not end in one with `Non-text file`. The boot then
  # fails although the VM is up. Appending the newline is idempotent.
  #
  # `machine ssh` refuses a VM Podman already gave up on, so the guest is
  # reached over its forwarded SSH port directly.
  def normalize_guest_subids
    ssh = machine_ssh_command
    return unless ssh

    # The trailing `true` keeps the exit status zero once the files are fine.
    script = %q(sudo sh -c 'for f in /etc/subuid /etc/subgid; do [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ] && echo >> "$f"; done; true')
    # A short timeout: an unreachable VM must not eat the whole retry budget.
    shell_out!(*ssh, script, timeout: 120)
  rescue Mixlib::ShellOut::ShellCommandFailed, Mixlib::ShellOut::CommandTimeout => e
    Chef::Log.warn("#{new_resource.machine_name}: could not repair the guest subuid files: #{e.message}")
  end

  def machine_ssh_command
    info = machine_info
    identity = info&.dig('SSHConfig', 'IdentityPath')
    port = info&.dig('SSHConfig', 'Port')
    user = info&.dig('SSHConfig', 'RemoteUsername') || 'core'
    return if identity.nil? || port.nil?

    ['ssh', '-i', identity, '-p', port.to_s, '-o', 'StrictHostKeyChecking=no',
     '-o', 'UserKnownHostsFile=/dev/null', '-o', 'ConnectTimeout=15', "#{user}@127.0.0.1"]
  end

  # `machine stop` succeeds on a running VM even when its state is unknown and
  # fails when it is already stopped, so failures are swallowed. Podman 4 also
  # leaves the qemu process behind when it gave up on the boot, so the pid file
  # is terminated as well.
  def stop_machine
    podman_execute!('machine', 'stop', new_resource.machine_name)
  rescue Mixlib::ShellOut::ShellCommandFailed
    nil
  ensure
    kill_machine_vm
  end

  # The VM and the port forwarder both have to be gone before the next boot: a
  # forwarder that is still shutting down keeps the forwarded SSH port, and the
  # new boot then cannot bind it. Podman removes the pid files as soon as it
  # gives up on a boot while both processes keep running, so they are also
  # looked up by their runtime socket names.
  def machine_processes
    dir = ::File.join(machine_runtime_dir, 'podman')
    name = new_resource.machine_name
    from_files = ["#{name}_vm.pid", "#{name}_proxy.pid"].filter_map do |file|
      read_pid(::File.join(dir, file))
    end
    pattern = "#{Regexp.escape(dir)}/#{Regexp.escape(name)}_(qmp|proxy|ready)\\.sock"
    found = shell_out('pgrep', '-f', pattern)
    from_files + (found.exitstatus.zero? ? found.stdout.split.map(&:to_i) : [])
  end

  def read_pid(path)
    pid = ::File.read(path).to_i
    pid.zero? ? nil : pid
  rescue SystemCallError
    nil
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    # A killed process stays a zombie until its parent reaps it; it still
    # answers signal 0 but no longer holds its sockets.
    return true unless ::File.exist?('/proc/self')

    ::File.read("/proc/#{pid}/stat")[/\)\s(\S)/, 1] != 'Z'
  rescue Errno::ESRCH, Errno::ENOENT
    false
  end

  def wait_for_processes(pids, timeout)
    deadline = ::Time.now + timeout
    loop do
      return true if pids.none? { |pid| process_alive?(pid) }
      return false if ::Time.now > deadline

      sleep 1
    end
  end

  def signal_process(pid, signal)
    Process.kill(signal, pid)
  rescue Errno::ESRCH
    nil
  end

  def kill_machine_vm
    pids = machine_processes.uniq
    pids.each { |pid| signal_process(pid, 'TERM') }
    unless wait_for_processes(pids, 20)
      pids.each { |pid| signal_process(pid, 'KILL') }
      wait_for_processes(pids, 10)
    end
    clean_machine_runtime_files
  end

  # Killing qemu behind Podman's back leaves its socket and pid files in the
  # runtime directory. `machine start` dials the socket of a known pid and
  # fails with `connect: no such file or directory` instead of booting anew.
  def clean_machine_runtime_files
    dir = ::File.join(machine_runtime_dir, 'podman')
    name = new_resource.machine_name
    ["qmp_#{name}.sock", "#{name}_ready.sock", "#{name}_vm.pid", "#{name}_proxy.pid"].each do |file|
      ::FileUtils.rm_f(::File.join(dir, file))
    end
  end

  # systemd-logind usually creates the per-user runtime directory, but not
  # everywhere (containers, minimal installs). Podman keeps the qemu sockets
  # there and does not recreate the directory for `machine start`, so a boot
  # after a `machine stop` fails with `qmp_*.sock: no such file`.
  def prepare_runtime_dir
    dir = ::File.join(machine_runtime_dir, 'podman')
    ::FileUtils.mkdir_p(dir)
    ::FileUtils.chown(::Etc.getpwnam(new_resource.run_as).uid, nil, dir) if new_resource.run_as
  rescue ArgumentError, SystemCallError => e
    Chef::Log.warn("#{new_resource.machine_name}: could not prepare the runtime directory: #{e.message}")
  end

  # Runs any command that boots a machine and retries when Podman gives up on
  # the boot before SSH answers. That happens without hardware virtualization,
  # where a boot easily outlasts Podman's own wait. Podman stops the port
  # forwarder when it gives up, so the still running VM is unreachable and has
  # to be stopped; the next boot starts from the already provisioned disk.
  def boot_machine(*args)
    remaining = new_resource.start_attempts
    begin
      prepare_runtime_dir
      podman_execute!(*args)
    rescue Mixlib::ShellOut::ShellCommandFailed, Mixlib::ShellOut::CommandTimeout => e
      raise unless e.message.match?(/did not transition into running state|exit status 1|received '125'/)

      # The boot itself may have been fine and only the post-boot step failed,
      # so repair what Podman 4 gets wrong in the guest before retrying.
      Chef::Log.warn("#{new_resource.machine_name}: boot attempt failed: #{e.message}")
      normalize_guest_subids

      # Podman leaves the VM running but unreachable, so stop it either way.
      attempts_left = (remaining -= 1)
      if attempts_left < 1
        stop_machine
        raise
      end

      Chef::Log.warn("#{new_resource.machine_name} did not answer in time, restarting the machine for another boot")
      stop_machine
      # The machine exists after the first attempt, so an init retry starts it.
      args = ['machine', 'start', new_resource.machine_name]
      retry
    end
  end
end
