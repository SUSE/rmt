class DownloadedFile < ApplicationRecord
  class << self
    def track_file(checksum_type:, checksum:, local_path:, size:)
      find_or_initialize_by(local_path: local_path).tap do |record|
        record.checksum_type = checksum_type
        record.checksum = checksum
        record.file_size = size

        record.save if record.changed?
      end.persisted?
    end

    def untrack_file(local_path)
      where(local_path: local_path).destroy_all
    end

  end

  def size
    file_size
  end
end
