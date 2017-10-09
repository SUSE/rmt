require 'config'
require 'rmt'

Config.load_and_set_settings(
  '/etc/rmt.conf',
  File.join(__dir__, '../../config/rmt.yml'),
  File.join(__dir__, '../../config/rmt.local.yml')
)

module RMT::Config
  def self.db_config
    {
      'host'     => Settings.database.host,
      'username' => Settings.database.username,
      'password' => Settings.database.password,
      'database' => Settings.database.database,
      'adapter'  => Settings.database.adapter,
      'encoding' => Settings.database.encoding,
      'timeout'  => Settings.database.timeout,
      'pool'     => Settings.database.pool
    }
  end
end
