require 'config'
require_relative '../rmt'

Config.setup do |config|
  config.merge_nil_values = false
end

Config.load_and_set_settings(
  '/etc/rmt.conf',
  File.join(__dir__, '../../config/rmt.yml'),
  File.join(__dir__, '../../config/rmt.local.yml')
)

module RMT::Config
  def self.db_config(key = 'database')
    {
      'host'     => Settings[key].host,
      'username' => Settings[key].username,
      'password' => Settings[key].password,
      'database' => Settings[key].database,
      'adapter'  => Settings[key].adapter,
      'encoding' => Settings[key].encoding,
      'timeout'  => Settings[key].timeout,
      'pool'     => Settings[key].pool
    }
  end

  ##
  # This method checks whether or not deduplication should be done by hardlinks.
  # If hardlinks are not used, the file will be copied instead.
  def self.deduplication_by_hardlink?
    Settings['mirroring'].dedup_method.to_s.to_sym != :copy
  end

end
