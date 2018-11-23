require 'registration_sharing/client'

# synchronizes marked systems with peer RMT servers
class RegistrationSharing::SyncJob
  def initialize
    @data_dir = RegistrationSharing.config_data_dir
    @peers = {}
  end

  def run
    populate_peer_data
    return unless @peers

    sync_registrations while @peers.present?
  end

  protected

  def populate_peer_data
    peer_hostnames = RegistrationSharing.config_peers
    peer_hostnames.each do |peer_hostname|
      next if @peers[peer_hostname]

      peer_data_dir = File.join(@data_dir, peer_hostname)
      next unless File.directory?(peer_data_dir)

      @peers[peer_hostname] = {
        data_dir: peer_data_dir,
        iterator: ::Dir.foreach(peer_data_dir)
      }
    end
  end

  # evenly drains all peer regsharing directories
  def sync_registrations
    @peers.each do |peer_hostname, peer_data|
      begin
        filename = peer_data[:iterator].next
      rescue StopIteration
        @peers.delete(peer_hostname)
        next
      end

      full_path = File.join(peer_data[:data_dir], filename)
      next unless File.file?(full_path)

      lock_data = read_file(full_path)

      client = RegistrationSharing::Client.new(peer_hostname, filename)

      begin
        client.sync_system
        unlink_file_if_unchanged(full_path, lock_data)
        Rails.logger.info("Synced #{filename} to #{peer_hostname}")
      rescue StandardError => e
        Rails.logger.error("Error while syncing #{filename} to #{peer_hostname}: #{e}")
      end
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
      File.unlink(filename) if (data == previous_data)
    end
  end
end
