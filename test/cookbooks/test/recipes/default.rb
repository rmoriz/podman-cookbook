# frozen_string_literal: true

podman_service 'default' do
  action %i(create start)
end
