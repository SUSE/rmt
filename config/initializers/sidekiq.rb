# frozen_string_literal: true

# Sidekiq configuration for RMT.
#
# We use the REDIS_URL environment variable for connection details.
# In RMT, this is typically configured via systemd environment files
# or /etc/rmt.conf in production environments.
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    namespace: 'rmt_sidekiq' # Ensures RMT jobs don't collide with other apps on the same Redis/Valkey instance
  }

  # Ensure the Sidekiq logger uses the same formatting or output stream as RMT
  # This helps when viewing logs via journalctl -u rmt-sidekiq
  config.logger.level = Logger::INFO
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    namespace: 'rmt_sidekiq'
  }
end
