# frozen_string_literal: true

# Sidekiq configuration for RMT.
#
# We use the REDIS url from the RMT config, which reads from
# REDIS_URL ENV by default, with fallback to 127.0.0.1:6379
redis_config = {
  url: Settings.try(:redis).try(:url) || 'redis://127.0.0.1:6379/0',
  connect_timeout: 10,
  reconnect_attempts: 3,
  namespace: 'rmt_sidekiq'
}

Sidekiq.configure_server do |config|
  config.redis = redis_config

  # Ensure the Sidekiq logger uses the same formatting or output stream as RMT
  # This helps when viewing logs via journalctl -u rmt-sidekiq
  config.logger.level = Logger::INFO
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
