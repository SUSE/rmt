$LOAD_PATH.push File.expand_path(__dir__, '..')

require 'registration_sharing/engine'
require 'registration_sharing/client'

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

    # synchronizes marked systems with peer RMT servers
    def sync_marked_systems
      peers = config_peers
      return unless peers

      data_dir = config_data_dir
      unless data_dir
        Rails.logger.warn 'Regsharing data directory does not exist'
        return
      end

      peers.each do |peer|
        peer_dir = File.join(data_dir, peer)
        unless File.directory?(peer_dir)
          log.info "Peer '#{peer}' directory doesn't exist, skipping"
          next
        end

        ::Dir.foreach(peer_dir) do |login|
          filename = File.join(peer_dir, login)
          next unless File.file?(filename)

          lock_data = read_file(filename)

          client = RegistrationSharing::Client.new(peer, login)
          client.sync_system

          unlink_file_if_unchanged(filename, lock_data)
          break
        end
      end
    end

    protected

    def config_peers
      return unless Settings[:regsharing]
      peers = Settings[:regsharing][:peers]
      return if peers.blank?

      (peers.class == String) ? [peers] : peers
    end

    def config_data_dir
      if Settings[:regsharing] && Settings[:regsharing][:data_dir]
        Settings[:regsharing][:data_dir]
      else
        RMT_REGSHARING_DEFAULT_DATA_DIR
      end
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

    def read_file(filename)
      File.open(filename, 'r') do |f|
        f.flock(File::LOCK_EX)
        return f.read
      end
    end

    def unlink_file_if_unchanged(filename, previous_data)
      File.open(filename, 'r') do |f|
        f.flock(File::LOCK_EX)
        data = f.read
        if (data == previous_data)
          File.unlink(filename)
          return true
        end
      end

      false
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
