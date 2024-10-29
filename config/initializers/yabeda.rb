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
  group :rake, &assign_labels

  group :rails do
    counter :started_requests_total,
            comment: 'A counter of the total number of HTTP requests rails has started to process.',
            tags: %i[controller action format method]
  end

  group :rake do
    gauge :task_started_at,
          comment: 'Time when the task started: unix time with decimals',
          tags: %i[task_name]

    gauge :task_exit_status,
          comment: 'Task exit status. 1 means OK, 0 means failed, not present means no data',
          tags: %i[task_name]

    gauge :task_duration_ms,
          comment: 'Time taken running the task',
          tags: %i[task_name]

    gauge :task_finished_at,
          comment: 'Time when the task finished: unix time with decimals',
          tags: %i[task_name]
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

ActiveSupport::Notifications.subscribe 'task_run.rake' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  task_name = event.payload[:task_name]

  success = 1
  if !!(event.payload[:exception] || event.payload[:exception_class])
    success = 0
  end

  Yabeda.rake.task_duration_ms.set({ task_name: task_name }, event.duration)
  Yabeda.rake.task_started_at.set({ task_name: task_name }, event.time / 1000.0)
  Yabeda.rake.task_finished_at.set({ task_name: task_name }, event.end / 1000.0)

  Yabeda.rake.task_exit_status.set({ task_name: task_name }, success)
end
