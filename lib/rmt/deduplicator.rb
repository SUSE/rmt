require 'fileutils'

class RMT::Deduplicator

  class MismatchException < RuntimeError
  end

  class HardlinkException < RuntimeError
  end

  class << self

    private

    def hardlink(src, dest)
      ::FileUtils.ln(src, dest)
    rescue StandardError
      raise ::RMT::Deduplicator::HardlinkException.new("#{src} → #{dest}")
    end

    def copy(src, dest)
      ::FileUtils.cp(src, dest)
    end

  end

  def self.add_local(path, checksum_type, checksum)
    file_size = File.size(path)
    DownloadedFile.add_file(checksum_type, checksum, file_size, path)
  end

  def self.deduplicate(checksum_type, checksum_value, destination, force_copy: false)
    src = DownloadedFile.get_local_path_by_checksum(checksum_type, checksum_value)

    if src.nil?
      return false
    elsif !File.exist?(src.local_path) || (src.file_size != File.size(src.local_path))
      raise MismatchException.new(src.local_path)
    end

    if RMT::Config.deduplication_by_hardlink? && !force_copy
      hardlink(src.local_path, destination)
    else
      copy(src.local_path, destination)
    end

    true
  end

end
