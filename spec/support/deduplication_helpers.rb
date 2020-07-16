def deduplication_method(method)
  Settings['mirroring'].dedup_method = method
end

def add_downloaded_file(checksum_type, checksum, path)
  DownloadedFile.add_file(checksum_type, checksum, path)
rescue StandardError
  nil
end

def deduplicate(checksum_type, checksum, path, track: true)
  ::RMT::Deduplicator.deduplicate(checksum_type, checksum, path, track: track)
rescue ::RMT::Deduplicator::MismatchException
  false
end
