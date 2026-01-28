# :nocov:
require 'config'
require_relative '../rmt'

Config.setup do |config|
  config.merge_nil_values = false
end

module RMT::Config

  # In specs, configuration will only be loaded from 'config/rmt.yml'
  CONFIG_FILES = [
    '/etc/rmt.conf',
    File.expand_path('../../config/rmt.yml', __dir__),
    File.expand_path('../../config/rmt.local.yml', __dir__)
  ].freeze

  class << self
    def load
      sources = CONFIG_FILES.select { |f| File.readable?(f) }
      Config.load_and_set_settings(*sources)
    end

    def db_config(key = 'database')
      {
        'username' => Settings[key].username,
        'password' => Settings[key].password,
        'database' => Settings[key].database,
        'host'     => Settings[key].host     || 'localhost',
        'adapter'  => Settings[key].adapter  || 'mysql2',
        'encoding' => Settings[key].encoding || 'utf8',
        'timeout'  => Settings[key].timeout  || 5000,
        'pool'     => Settings[key].pool     || 5
      }
    end

    # This method checks whether or not deduplication should be done by hardlinks.
    # If hardlinks are not used, the file will be copied instead.
    def deduplication_by_hardlink?
      Settings.try(:mirroring).try(:dedup_method).to_s.to_sym != :copy
    end

    # This method checks whether to re-validate metadata content and packages
    # when the metadata did not change (default=true)
    def revalidate_repodata?
      return true if Settings.try(:mirroring).try(:revalidate_repodata).nil?

      ActiveModel::Type::Boolean.new.cast(Settings.mirroring.revalidate_repodata)
    end

    def mirror_src_files?
      ActiveModel::Type::Boolean.new.cast(Settings.try(:mirroring).try(:mirror_src))
    end

    def mirror_drpm_files?
      mirror_drpm_files = ActiveModel::Type::Boolean.new.cast(Settings.try(:mirroring).try(:mirror_drpm))
      mirror_drpm_files.nil? ? true : mirror_drpm_files
    end

    def redirect_repo_hosts
      hosts = Settings&.mirroring&.redirect_repo_hosts
      hosts.is_a?(Array) && hosts.present? && hosts.all?(String) ? hosts : nil
    end

    WebServerConfig = Struct.new(
      'WebServerConfig',
      :max_threads, :min_threads, :workers,
      keyword_init: true
    )

    def web_server
      WebServerConfig.new(
        max_threads: validate_int(Settings.try(:web_server).try(:max_threads)) || 5,
        min_threads: validate_int(Settings.try(:web_server).try(:min_threads)) || 5,
        workers:     validate_int(Settings.try(:web_server).try(:workers))     || 2
      )
    end

    def set_host_system!
      Settings[:host_system] = host_system
    end

    private

    def host_system
      return '' if !File.exist?(RMT::CREDENTIALS_FILE_LOCATION) ||
                   !File.readable?(RMT::CREDENTIALS_FILE_LOCATION)

      File.foreach(RMT::CREDENTIALS_FILE_LOCATION) do |line|
        m = line.match(/username=(.+)/)
        return m[1] if m
      end

      ''
    end

    def validate_int(value)
      converted_value = Integer(value) rescue nil
      return nil if converted_value.nil? || converted_value < 1

      converted_value
    end
  end
end
# :nocov:
