# :nocov:
require 'config'
require 'dry-initializer'
require 'dry-schema'
require 'forwardable'
require_relative '../rmt'

Config.setup do |config|
  config.merge_nil_values = false
end

# In specs, configuration will only be loaded from 'config/rmt.yml'
Config.load_and_set_settings(
  ('/etc/rmt.conf' if File.readable?('/etc/rmt.conf')),
  File.join(__dir__, '../../config/rmt.yml'),
  File.join(__dir__, '../../config/rmt.local.yml')
)

# unless RMT::Config.is_valid?
#   warn "Credentials file (#{RMT::CREDENTIALS_FILE_LOCATION}) is not readable by user '#{RMT::CLI::Base.process_user_name}'"
#   warn 'Run as root or adjust the permissions.'
# end

class DatabaseConfigSchema
  extend Dry::Initializer

  option :username, Dry::Types['strict.string'] 
  option :password, Dry::Types['strict.string'] 
  option :database, Dry::Types['strict.string'] 
  option :host, Dry::Types['strict.string'], default: proc {'localhost'}
  option :adapter, Dry::Types['strict.string'], default: proc {'mysql2'}
  option :encoding, Dry::Types['strict.string'], default: proc {'utf8'}
  option :timeout, Dry::Types['strict.integer'], default: proc {5000}
  option :pool, Dry::Types['strict.integer'], default: proc {5}
end

class SCCMetricsConfigSchema
  extend Dry::Initializer

  option :enabled, Dry::Types['strict.string'], default: proc {false}
  option :job_name, Dry::Types['strict.string'], default: proc {'rmt'}
end

class SCCConnectionConfigSchema
  extend Dry::Initializer

  option :username, Dry::Types['strict.string'] 
  option :password, Dry::Types['strict.string']
  option :sync_systems, Dry::Types['strict.string'], default: proc {true}
  option :metrics, Dry::Types['strict.string']
end

class SCCMirroringConfigSchema
  extend Dry::Initializer

  option :mirror_drpm, Dry::Types['strict.bool'], default: proc {true} # .default(true)
  option :mirror_src,  Dry::Types['strict.bool'], default: proc {false} # .default(false)
  option :revalidate_repodata, Dry::Types['strict.bool'], default: proc {true}
  option :dedup_method, Dry::Types['strict.string'], default: proc {'copy'}
end

class HTTPClientConfigSchema
  extend Dry::Initializer

  option :verbose, Dry::Types['strict.string'], default: proc {false}
  option :proxy, Dry::Types['strict.string']
  option :proxy_auth, Dry::Types['strict.string']
  option :proxy_user, Dry::Types['strict.string']
  option :proxy_password, Dry::Types['strict.string']
  option :low_speed_limit,Dry::Types['strict.integer'], default: proc {512}
  option :low_speed_time, Dry::Types['strict.integer'], default: proc {120}
end
# log_level:
class LogLevelConfigSchema
  extend Dry::Initializer

  option :rails, Dry::Types['strict.string'], default: proc {'info'}
  option :cli, Dry::Types['strict.string'], default: proc {'info'}
end

# web_server:
class WebServerConfigSchema 
  extend Dry::Initializer

  option :min_threads, Dry::Types['strict.integer'], default: proc {5}
  option :max_threads, Dry::Types['strict.integer'], default: proc {5}
  option :workers, Dry::Types['strict.integer'], default: proc {2}
end

module RMT 
  # RMT::Config.instance.mirroring  
  class Config 
    # include Singleton
    extend Dry::Initializer
    extend SingleForwardable

    # def_single_delegator :instance, :mirror_drpm_files?, :'mirroring.mirror_drpm.present'

    option :database # ).filled(DatabaseConfigSchema)
    option :mirroring # ).filled(SCCMirroringConfigSchema)
    option :http_client # ).filled(HTTPClientConfigSchema)
    option :log_level # ).filled(LogLevelConfigSchema)
    option :web_server # ).filled(WebServerConfigSchema)
    option :host_system # ).filled(:string)
    
    def method_missing(m, *args, &block)
      instance.send(*args) || instance.class.send(*args)
    end
    

    def self.db_config(key = 'database')
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
      mirroring?.dedup_method?.to_sym != :copy
    end

    # This method checks whether to re-validate metadata content and packages
    # when the metadata did not change (default=true)
    def self.revalidate_repodata?
      instance.!mirroring?.revalidate_repodata?.present?
    end

    def self.mirror_src_files?
      instance.mirroring?.mirror_src?
    end

    def mirror_drpm_files?
      mirror_drpm_files = ActiveModel::Type::Boolean.new.cast(Settings.try(:mirroring).try(:mirror_drpm))
      mirror_drpm_files.nil? ? true : mirror_drpm_files
      ¹instance.mirroring?.mirror_drpm.present?
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
  end
end
# :nocov:
