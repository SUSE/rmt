class RMT::ChecksumVerifier
  KNOWN_HASH_FUNCTIONS = %i[MD5 SHA1 SHA256 SHA384 SHA512].freeze

  class Exception < RuntimeError
  end

  def self.verify_checksum(checksum_type, checksum_value, file_path)
    hash_function = checksum_type.gsub(/\W/, '').upcase.to_sym
    hash_function = :SHA1 if (hash_function == :SHA)

    unless KNOWN_HASH_FUNCTIONS.include? hash_function
      raise RMT::ChecksumVerifier::Exception.new(_('Unknown hash function %{checksum_type}') % { checksum_type: checksum_type })
    end

    digest = Digest.const_get(hash_function).file(file_path)

    raise RMT::ChecksumVerifier::Exception.new(_("Checksum doesn't match")) unless (checksum_value == digest.to_s)
  end

end
