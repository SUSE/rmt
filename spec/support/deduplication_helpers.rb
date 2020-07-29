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

def deduplicate(checksum_type, checksum, path, track: true)
  ::RMT::Deduplicator.deduplicate(checksum_type, checksum, path, track: track)
rescue ::RMT::Deduplicator::MismatchException
  false
end
