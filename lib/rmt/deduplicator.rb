require 'fileutils'

module RMT::Deduplicator
  class HardlinkException < RuntimeError
  end

  private

  def deduplicate(target_file)
    source_files = find_valid_files_by_checksum(
      target_file.checksum, target_file.checksum_type
    )

    return false if source_files.empty?

    make_file_dir(target_file.local_path)
    source_file_path = source_files.first.local_path

    if RMT::Config.deduplication_by_hardlink? && !is_airgapped
      hardlink(source_file_path, target_file.local_path)
      logger.info("← #{File.basename(target_file.local_path)}")
    else
      copy(source_file_path, target_file.local_path)
      logger.info("→ #{File.basename(target_file.local_path)}")
    end

    # we don't want to track airgap files in our database
    unless is_airgapped
      DownloadedFile.track_file(checksum: target_file.checksum,
                                checksum_type: target_file.checksum_type,
                                local_path: target_file.local_path,
                                size: File.size(target_file.local_path))
    end
    true
  end

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
