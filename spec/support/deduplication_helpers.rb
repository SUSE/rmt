def deduplication_method(method)
  Settings['mirroring'].dedup_method = method
end

def deduplicate(checksum_type, checksum, path)
  ::RMT::Deduplicator.deduplicate(checksum_type, checksum, path)
rescue ::RMT::Deduplicator::MismatchException
  false
end
