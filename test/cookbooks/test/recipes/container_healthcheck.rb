# frozen_string_literal: true

podman_container 'health-checked' do
  repo 'busybox'
  command 'sleep 300'
  health_check(
    'Test' => ['CMD-SHELL', 'curl -f http://localhost'],
    'Interval' => '1.5s',
    'Timeout' => '5s',
    'Retries' => 3,
    'StartPeriod' => '10s'
  )
  action :create
end
