require 'rmt/checksum_verifier'

class DownloadedFile < ApplicationRecord

  def self.add_file!(checksum_type, checksum, local_path)
    return nil unless local_path.match?(/\.(rpm|drpm)$/)
    file_size = File.size(local_path)
    DownloadedFile.create({ checksum_type: checksum_type,
                            checksum: checksum,
                            local_path: local_path,
                            file_size: file_size })
  rescue StandardError => e
    # de-duplication is not critical, just move on
    logger.error e.message
    logger.error e.backtrace.each { |line| logger.error line }
  end

  def self.get_local_path_by_checksum(checksum_type, checksum)
    file = DownloadedFile.find_by({ checksum_type: checksum_type,
                                    checksum: checksum })
    return nil if file.nil? || file.file_size != File.size(file.local_path)
    file.local_path
  rescue StandardError => e
    # de-duplication is not critical, just return nil to download again
    logger.error e.message
    logger.error e.backtrace.each { |line| logger.error line }
    nil
  end

end
