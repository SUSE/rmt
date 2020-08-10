require 'fileutils'

class RMT::FileValidator
  class << self
    def validate_local_file(file_reference, deep_verify:)
      valid_on_disk = verify_file_on_disk(file_reference, deep_verify)
      update_file_status_in_database(file_reference, valid_on_disk)

      valid_on_disk
    end

    def find_valid_file_by_checksum(checksum, checksum_type, deep_verify:)
      valid_files = DownloadedFile
        .where(checksum: checksum, checksum_type: checksum_type).map do |file|
          valid_on_disk = verify_file_on_disk(file, deep_verify)
          file.destroy unless valid_on_disk

          valid_on_disk ? file.local_path : nil
        end

      valid_files.compact.first
    end

    private

    def verify_file_on_disk(file, deep_verify)
      return false unless File.exist?(file.local_path)

      has_valid_metadata = (File.size(file.local_path) == file.size)
      if deep_verify
        has_valid_metadata &= RMT::ChecksumVerifier
          .match_checksum?(file.checksum_type, file.checksum, file.local_path)
      end
      return true if has_valid_metadata

      FileUtils.remove_file(file.local_path, force: true)
      false
    end

    def update_file_status_in_database(file, valid_on_disk)
      if valid_on_disk
        DownloadedFile.track_file(checksum: file.checksum,
                                  checksum_type: file.checksum_type,
                                  local_path: file.local_path,
                                  size: file.size)
        return
      end

      DownloadedFile.where(local_path: file.local_path).destroy_all
    end
  end
end
