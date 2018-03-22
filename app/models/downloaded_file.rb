class DownloadedFile < ApplicationRecord

  def self.add_file(checksum_type, checksum, file_size, local_path)
    return unless local_path.match?(/\.(rpm|drpm)$/)

    DownloadedFile.create({ checksum_type: checksum_type,
                            checksum: checksum,
                            local_path: local_path,
                            file_size: file_size })
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def self.get_local_path_by_checksum(checksum_type, checksum)
    DownloadedFile.find_by({ checksum_type: checksum_type, checksum: checksum })
  end

end
