require 'config'

Config.load_and_set_settings(
  '/etc/rmt.conf',
  File.join(__dir__, '../../config/rmt.yml'),
  File.join(__dir__, '../../config/rmt.local.yml')
)
