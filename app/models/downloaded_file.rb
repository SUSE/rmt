class DownloadedFile < ApplicationRecord

  def self.add_file(checksum_type, checksum, local_path)
    return unless local_path.match?(/\.(rpm|drpm)$/)

    file_size = File.size(local_path)
    DownloadedFile.create({ checksum_type: checksum_type,
                            checksum: checksum,
                            local_path: local_path,
                            file_size: file_size })
  end

  def self.get_local_path_by_checksum(checksum_type, checksum)
    DownloadedFile.find_by({ checksum_type: checksum_type, checksum: checksum })
  end

end
