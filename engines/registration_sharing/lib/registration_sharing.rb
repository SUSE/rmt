$LOAD_PATH.push File.expand_path(__dir__, '..')

require 'registration_sharing/engine'

module RegistrationSharing
  RMT_REGSHARING_DEFAULT_DATA_DIR = '/var/lib/rmt/regsharing'.freeze

  class << self
    def share(obj)
      peers = config_peers
      return unless peers

      system = (obj.class <= ::System) ? obj : obj.system

      peers.each do |peer|
        write_file(peer, system.login)
      end
    end

    def config_peers
      return unless Settings[:regsharing]
      peers = Settings[:regsharing][:peers]
      return if peers.blank?

      (peers.class == String) ? [peers] : peers
    end

    def config_data_dir
      Settings[:regsharing][:data_dir] || RMT_REGSHARING_DEFAULT_DATA_DIR
    end

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
