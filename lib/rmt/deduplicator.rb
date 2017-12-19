require 'fileutils'

class RMT::Deduplicator

  class MismatchException < RuntimeError
  end


  def self.deduplicate(checksum_type, checksum_value, destination)
    src = DownloadedFile.get_local_path_by_checksum(checksum_type, checksum_value)

    if src.nil?
      return false
    elsif !File.exist?(src.local_path) || (src.file_size != File.size(src.local_path))
      raise MismatchException
    end

    if RMT::Config.deduplication_by_hardlink?
      ::FileUtils.ln(src.local_path, destination)
    else
      ::FileUtils.cp(src.local_path, destination)
    end

    true
  end

end
