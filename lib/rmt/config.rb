require 'config'

Config.load_and_set_settings(
  File.join(File.dirname(__FILE__), '../../config/rmt.yml'),
  File.join(File.dirname(__FILE__), '../../config/rmt.local.yml')
)
