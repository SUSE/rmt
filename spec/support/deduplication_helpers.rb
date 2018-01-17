def deduplication_method(method)
  Settings['mirroring'].dedup_method = method
end

def add_downloaded_file(checksum_type, checksum, path)
  DownloadedFile.add_file(checksum_type, checksum, File.size(path), path)
rescue StandardError
  nil
end

def deduplicate(checksum_type, checksum, path)
  ::RMT::Deduplicator.deduplicate(checksum_type, checksum, path)
rescue ::RMT::Deduplicator::MismatchException
  false
end
