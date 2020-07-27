class DownloadedFile < ApplicationRecord
  class << self

    def get_local_path_by_checksum(checksum_type, checksum)
      DownloadedFile.find_by({ checksum_type: checksum_type, checksum: checksum })
    end

    def valid_local_file?(checksum_type, checksum_value, path)
      return false unless File.exist?(path)

      valid_checksum = RMT::ChecksumVerifier.match_checksum?(checksum_type, checksum_value, path)
      tracked_file = find_by(local_path: path)
      matched_tracked_file = matches_tracked_file?(tracked_file, checksum_type, checksum_value)

      return true if valid_checksum && matched_tracked_file

      if valid_checksum && tracked_file.nil?
        return !track_file(checksum_type: checksum_type,
                           checksum: checksum_value,
                           local_path: path,
                           size: File.size(path)).nil?
      end

      FileUtils.remove_file(path, force: true)
      tracked_file.destroy unless tracked_file.nil?
      false
    end

    def track_file(checksum_type:, checksum:, local_path:, size:)
      find_or_initialize_by(local_path: local_path).tap do |record|
        record.checksum_type = checksum_type
        record.checksum = checksum
        record.file_size = size

        record.save if record.changed?
      end.persisted?
    end

    def untrack_file(local_path)
      where(local_path: local_path).destroy_all
    end

    private

    def matches_tracked_file?(tracked_file, checksum_type, checksum_value)
      return false if tracked_file.nil? || tracked_file.checksum_type != checksum_type || tracked_file.checksum != checksum_value
      true
    end

  end
end
