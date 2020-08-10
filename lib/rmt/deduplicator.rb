require 'fileutils'

class RMT::Deduplicator

  class HardlinkException < RuntimeError
  end

  class << self

    def deduplicate(target_file, force_copy: false, track: true)
      source_files = ::RMT::FileValidator.find_valid_files_by_checksum(
        target_file.checksum, target_file.checksum_type, deep_verify: false
      )

      return false if source_files.empty?

      make_file_dir(target_file.local_path)
      source_file_path = source_files.first.local_path

      if RMT::Config.deduplication_by_hardlink? && !force_copy
        hardlink(source_file_path, target_file.local_path)
      else
        copy(source_file_path, target_file.local_path)
      end

      if track
        DownloadedFile.track_file(checksum: target_file.checksum,
                                  checksum_type: target_file.checksum_type,
                                  local_path: target_file.local_path,
                                  size: File.size(target_file.local_path))
      end

      true
    end

    private

    def hardlink(src, dest)
      FileUtils.ln(src, dest)
    rescue StandardError
      raise RMT::Deduplicator::HardlinkException.new("#{src} → #{dest}")
    end

    def copy(src, dest)
      FileUtils.cp(src, dest)
    end

    def make_file_dir(file_path)
      dirname = File.dirname(file_path)

      FileUtils.mkdir_p(dirname)
    end

  end

end
