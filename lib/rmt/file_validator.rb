require 'fileutils'
require 'rmt/checksum_verifier'

class RMT::FileValidator
  class << self
    def validate_local_file(file_reference, deep_verify:)
      verify_file_on_disk(file_reference, deep_verify).tap do |valid_on_disk|
        verify_file_on_database(file_reference, valid_on_disk)
      end
    end

    private

    def verify_file_on_disk(file, deep_verify)
      file_exist = File.exist?(file.local_path)
      match_metadata = file_exist ? file_match_metadata?(file, deep_verify) : false

      return true if match_metadata

      FileUtils.remove_file(file.local_path, force: true) if file_exist

      false
    end

    def verify_file_on_database(file, valid_on_disk)
      if valid_on_disk
        ::DownloadedFile.track_file(
          checksum: file.checksum,
          checksum_type: file.checksum_type,
          local_path: file.local_path,
          size: file.size
        )

        return
      end

      ::DownloadedFile.untrack_file(file.local_path)
    end

    def file_match_metadata?(file, deep_verify)
      File.size(file.local_path) == file.size && file_match_checksum?(file, deep_verify)
    end

    def file_match_checksum?(file, deep_verify)
      return true unless deep_verify

      ::RMT::ChecksumVerifier
        .match_checksum?(file.checksum_type, file.checksum, file.local_path)
    end
  end
end
