# frozen_string_literal: true

# Sidekiq configuration for RMT.
#
# We use the REDIS_URL environment variable for connection details.
# In RMT, this is typically configured via systemd environment files
# or /etc/rmt.conf in production environments.
redis_config = {
  url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0'),
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
