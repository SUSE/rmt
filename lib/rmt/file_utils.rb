require 'fileutils'

class RMT::FileUtils

  def self.deduplicate(checksum_type, checksum_value, destination)
    local_path = DownloadedFile.get_local_path_by_checksum(checksum_type, checksum_value)
    return false unless local_path

    if RMT::Config.deduplication_by_hardlink?
      ::FileUtils.ln(local_path, destination)
    else
      ::FileUtils.cp(local_path, destination)
    end

    true
  end

end
