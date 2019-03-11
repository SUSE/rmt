$LOAD_PATH.push File.expand_path(__dir__, '..')

require 'registration_sharing/engine'

module RegistrationSharing
  RMT_REGSHARING_DEFAULT_DATA_DIR = '/var/lib/rmt/regsharing'.freeze

  class << self
    # creates a file on the disk to mark systems with changed registration data
    def save_for_sharing(obj)
      peers = config_peers
      return unless peers

      system = (obj.class <= ::System) ? obj : obj.system

      peers.each do |peer|
        write_file(peer, system.login)
      end
    end

    def config_peers
      peers = Settings[:regsharing][:peers] rescue nil
      return if peers.blank?

      (peers.class == String) ? [peers] : peers
    end

    # used by model callbacks to prevent triggering registration sharing from registration sharing controllers
    def called_from_regsharing?(call_data)
      call_data.each do |location|
        return true if location.absolute_path =~ /\bregistration_sharing\b/
      end

      false
    end

    def config_data_dir
      Settings[:regsharing][:data_dir] || RMT_REGSHARING_DEFAULT_DATA_DIR
    rescue StandardError
      RMT_REGSHARING_DEFAULT_DATA_DIR
    end

    def config_api_secret
      Settings[:regsharing][:api_secret] rescue nil
    end

    def config_ca_path
      Settings[:regsharing][:ca_path] rescue nil
    end

    protected

    def write_file(peer, system_login)
      dirname = File.join(config_data_dir, peer)
      FileUtils.mkpath(dirname)

      filename = File.join(config_data_dir, peer, system_login)

      File.open(filename, 'w') do |f|
        f.flock(File::LOCK_EX)
        f.puts(Time.now.to_f.to_s)
      end
    end


  end
end

module ::Rails
  class Application
    rake_tasks do
      Dir[File.join(__dir__, 'tasks/', '**/*.rake')].each do |file|
        load file
      end
    end
  end
end
