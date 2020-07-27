require 'fileutils'
require 'rmt/checksum_verifier'

class RMT::FileValidator
  class << self
    def validate_local_file(repository_dir:, metadata:, deep_verify:)
      verify_file_on_disk(repository_dir, metadata, deep_verify).tap do |(file_path, valid_file)|
        verify_file_on_database(file_path, valid_file, metadata)
      end
    end

    private

    def verify_file_on_disk(repository_dir, metadata, deep_verify)
      path = local_path(repository_dir, metadata)
      file_exist = File.exist?(path)
      match_metadata = file_exist ? file_match_metadata?(path, metadata, deep_verify) : false

      return [path, true] if match_metadata

      FileUtils.remove_file(path, force: true) if file_exist

      [path, false]
    end

    def verify_file_on_database(file_path, valid_file, metadata)
      if valid_file
        ::DownloadedFile.track_file(
          checksum: metadata.checksum,
          checksum_type: metadata.checksum_type,
          local_path: file_path,
          size: metadata.size
        )

        return
      end

      ::DownloadedFile.untrack_file(file_path)
    end

    def local_path(repository_dir, metadata)
      File.join(repository_dir, metadata.location.gsub(/\.\./, '__'))
    end

    def file_match_metadata?(path, metadata, deep_verify)
      File.size(path) == metadata.size && file_match_checksum?(path, metadata, deep_verify)
    end

    def file_match_checksum?(path, metadata, deep_verify)
      return true unless deep_verify

      ::RMT::ChecksumVerifier
        .match_checksum?(metadata.checksum_type, metadata.checksum, path)
    end
  end
end
