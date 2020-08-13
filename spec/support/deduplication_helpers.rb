def deduplication_method(method)
  Settings['mirroring'].dedup_method = method
end

def add_downloaded_file(checksum_type, checksum, path)
  size = File.size(path)

  DownloadedFile.track_file(checksum: checksum,
                            checksum_type: checksum_type,
                            local_path: path,
                            size: size)
end

def create_and_track_file(file_reference, fixture_path)
  if fixture_path
    FileUtils.mkdir_p(File.dirname(file_reference.local_path))
    FileUtils.cp(fixture_path, file_reference.local_path)
  end

  DownloadedFile.track_file(checksum: file_reference.checksum,
                            checksum_type: file_reference.checksum_type,
                            local_path: file_reference.local_path,
                            size: file_reference.size)
end

def deduplicate(checksum_type, checksum, path, track: true)
  ::RMT::Deduplicator.deduplicate(checksum_type, checksum, path, track: track)
rescue ::RMT::Deduplicator::MismatchException
  false
end
