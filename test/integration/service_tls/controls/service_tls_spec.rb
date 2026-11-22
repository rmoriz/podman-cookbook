control 'service-tls' do
  impact 1.0
  title 'The API server runs with the TLS material'

  tls = command('podman system service --help').stdout.include?('--tls-cert')

  describe command('ps -o args= -C podman') do
    its('stdout') { should match(/--tls-cert/) } if tls
    its('stdout') { should_not match(/--tls-cert/) } unless tls
  end

  # Podman below 5 has no TLS flags and serves the socket in plain HTTP.
  ping = if tls
           'curl -sk --unix-socket /run/podman/podman.sock --cert /etc/podman/client.crt --key /etc/podman/client.key https://d/_ping'
         else
           'curl -s --unix-socket /run/podman/podman.sock http://d/_ping'
         end

  describe command(ping) do
    its('stdout') { should match(/OK/) }
    its('exit_status') { should eq 0 }
  end
end
