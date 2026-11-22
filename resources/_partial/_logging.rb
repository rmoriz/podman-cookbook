# frozen_string_literal: true

# Podman supports a fixed set of log drivers; `json-file` is only an alias for
# `k8s-file`.
property :log_driver,
         [String, nil],
         equal_to: %w(k8s-file journald none passthrough passthrough-tty json-file),
         default: nil

property :log_opts,
         [Hash, nil],
         coerce: proc { |value| coerce_log_opts(value) }

def coerce_log_opts(value)
  case value
  when Hash, nil
    value
  else
    Array(value).each_with_object({}) do |log_opt, memo|
      key, _, val = log_opt.partition('=')
      memo[key] = val
    end
  end
end
