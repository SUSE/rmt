def configure_prometheus!(puma)
  ENV['STARTED_FROM_PUMA'] = '1'

  puma.activate_control_app
  puma.plugin :yabeda
  puma.plugin :yabeda_prometheus
end
