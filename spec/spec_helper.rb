# frozen_string_literal: true

require 'chefspec'
require 'chefspec/policyfile'

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.formatter = :documentation
  config.platform = 'ubuntu'
  config.version = '24.04'
end

# ChefSpec does not model the Podman CLI. Every shell_out call gets a benign
# result unless a spec stubs something more specific.
module PodmanShellOutStub
  def shell_out(*_args, **_options)
    instance_double(
      Mixlib::ShellOut,
      exitstatus: 0,
      stdout: '',
      stderr: '',
      error?: false,
      error!: nil
    )
  end
end

# Stands in for a Mixlib::ShellOut result so `error!` behaves like the real
# one when a call is meant to fail.
class PodmanShellResult
  attr_reader :exitstatus, :stdout, :stderr

  def initialize(stdout:, exitstatus:, stderr: '')
    @stdout = stdout.to_s
    @exitstatus = exitstatus
    @stderr = stderr.to_s
  end

  def error?
    !exitstatus.zero?
  end

  def error!
    # Match the shape of the real failure so resources can inspect `stderr`.
    raise Mixlib::ShellOut::ShellCommandFailed,
          "Expected process to exit with [0], but received '#{exitstatus}'\nSTDERR: #{stderr}" if error?

    self
  end
end

module PodmanSpecHelpers
  # The execute service manager only restarts the daemon when its pid file is
  # gone, the process is dead or the socket does not answer. That guard is one
  # shell command, so it is stubbed as a whole.
  def stub_service_running(pidfile, wait_ready, running: false)
    stub_command(
      "sh -c 'test -s #{pidfile} && kill -0 $(cat #{pidfile}) && #{wait_ready}'"
    ).and_return(running)
  end

  # Stubs every shell command call. Pass `stdout_for` with command fragments to
  # return specific output (for example an inspect document) and `failing_for`
  # with fragments that should exit non-zero. `stderr_for` and `failing_for`
  # together can simulate a failure the resource retries: pass
  # `retried_for: ['machine start']` to let only the first matching call fail.
  # A `stdout_for` value may be a callable for output that changes between
  # calls.
  # Every command is recorded in `podman_commands`.
  def stub_podman(stdout_for: {}, failing_for: [], stderr_for: {}, exit_codes: {}, retried_for: [])
    # Feature probes default to a current build; specs that cover an older
    # Podman override the entry.
    stdout_for = {
      'system service --help' => '      --tls-cert string   PEM file',
      'volume prune --help' => "  -a, --all\n",
    }.merge(stdout_for)
    retried = Hash.new(0)
    retried_for.each { |fragment| retried[fragment] = 0 }
    stub_command('sh -c "loginctl show-user podmanmachine --property=Linger | grep -q Linger=yes"').and_return(true)
    stub_command('sh -c "loginctl show-user podman --property=Linger | grep -q Linger=yes"').and_return(true)
    # The registry wait guards in the test recipes.
    stub_command('sh -c "podman exec test-registry wget -qO- http://127.0.0.1:5000/v2/ 2>/dev/null"').and_return(true)
    stub_command('curl -sf http://127.0.0.1:5003/v2/').and_return(true)

    # `shell_out` takes the command and its arguments either as one array or as
    # separate positional arguments, so both forms are joined into the recorded
    # command line.
    perform = lambda do |*args, **options|
      command = args.join(' ')
      podman_commands << command
      podman_environments << (options[:environment] || {})
      podman_inputs << options[:input]
      failing = failing_for.any? { |fragment| command.include?(fragment) }
      retried.each_key do |fragment|
        failing = false if command.include?(fragment) && (retried[fragment] += 1) > 1
      end
      code = exit_codes.find { |fragment, _| command.include?(fragment) }&.last
      output = stdout_for.find { |fragment, _| command.include?(fragment) }&.last
      output = output.call if output.respond_to?(:call)
      errors = stderr_for.find { |fragment, _| command.include?(fragment) }&.last

      PodmanShellResult.new(stdout: output, stderr: errors, exitstatus: code || (failing ? 1 : 0))
    end

    [Chef::Resource, Chef::Provider].each do |klass|
      allow_any_instance_of(klass).to receive(:shell_out) do |_instance, *args, **opts|
        perform.call(*args, **opts)
      end
      allow_any_instance_of(klass).to receive(:shell_out!) do |_instance, *args, **opts|
        perform.call(*args, **opts).error!
      end
    end
  end

  def podman_commands
    @podman_commands ||= []
  end

  # Environment hashes passed to the last commands, index-aligned with
  # `podman_commands`.
  def podman_environments
    @podman_environments ||= []
  end

  # Stdin passed to the commands, index-aligned with `podman_commands`.
  def podman_inputs
    @podman_inputs ||= []
  end
end

RSpec.configure do |config|
  config.include PodmanSpecHelpers
end

# The PartialHash type lives in a resource partial that needs the Chef DSL.
# Define the class for plain library specs.
class PartialHash < Hash
  def ==(other)
    other.is_a?(Hash) && all? { |key, value| other.key?(key) && other[key] == value }
  end
end unless defined?(PartialHash)
