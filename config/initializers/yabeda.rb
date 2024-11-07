# :nocov:
# frozen_string_literal: true

return unless Settings.dig(:scc, :metrics, :enabled)

# Configure prometheus client
Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(
  dir: './tmp/prometheus/'
)

# Configure yabeda
Yabeda.configure do
  assign_labels = lambda {
    default_tag :environment, Rails.env
    default_tag :application, 'rmt'
  }

  group :rails, &assign_labels

  group :rails do
    counter :started_requests_total,
            comment: 'A counter of the total number of HTTP requests rails has started to process.',
            tags: %i[controller action format method]
  end
end

# Instrument the request from the start
ActiveSupport::Notifications.subscribe 'start_processing.action_controller' do |*args|
  # Match the same event as Yabeda
  event = Yabeda::Rails::Event.new(*args)

  Yabeda.rails.started_requests_total.tap do |metric|
    labels = event.labels.slice(*metric.tags)

    metric.increment(labels, by: 1)
  end
end
# :nocov:
