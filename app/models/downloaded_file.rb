class DownloadedFile < ApplicationRecord
  class << self

    def add_file(checksum_type, checksum, local_path)
      return unless local_path.match?(/\.(rpm|drpm)$/)

      file_size = File.size(local_path)
      DownloadedFile.find_or_create_by({ checksum_type: checksum_type,
                                         checksum: checksum,
                                         local_path: local_path,
                                         file_size: file_size })
    end

    def get_local_path_by_checksum(checksum_type, checksum)
      DownloadedFile.find_by({ checksum_type: checksum_type, checksum: checksum })
    end

    def valid_local_file?(checksum_type, checksum_value, path)
      return false unless File.exist?(path)

      valid_checksum = RMT::ChecksumVerifier.match_checksum?(checksum_type, checksum_value, path)
      file_db_entries = where(local_path: path)
      matched_tracked_file = file_db_entries.find do |entry|
        match_tracked_file?(entry, checksum_type, checksum_value)
      end

      duplicated_entries = file_db_entries.select { |entry| entry != matched_tracked_file }
      duplicated_entries.each(&:destroy)

      return true if valid_checksum && matched_tracked_file
      return !add_file(checksum_type, checksum_value, path).nil? if valid_checksum && matched_tracked_file.nil?

      FileUtils.remove_file(path, force: true)
      matched_tracked_file.destroy unless matched_tracked_file.nil?

      false
    end

    private

    def match_tracked_file?(tracked_file, checksum_type, checksum_value)
      return false if tracked_file.nil? || tracked_file.checksum_type != checksum_type || tracked_file.checksum != checksum_value
      true
    end

  end
end
