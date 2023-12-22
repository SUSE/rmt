class RMT::Mirror::Debian < RMT::Mirror::Base
  RELEASE_FILE_NAME = 'Release'.freeze
  GPG_FILE_NAME = 'Release.gpg'.freeze
  KEY_FILE_NAME = 'Release.key'.freeze

  def mirror_implementation
    create_temp_dir(:metadata)
    release = download_cached!(repository_url(RELEASE_FILE_NAME), to: temp(:metadata))

  end

  def mirror_metadata(release_file)
    ref_config = {
      base_dir: temp(:metadata),
      base_url: repository_url
    }
    key_file = RMT::Mirror::FileReference.new(relative_path: GPG_FILE_NAME, **ref_config)
    signature_file = RMT::Mirror::FileReference.new(relative_path: KEY_FILE_NAME, **ref_config)
    check_signature(key_file: key_file, signature_file: signature_file, metadata_file: release_file)

    metadata_refs = parse_release_file(release_file)
    metadata_refs.each { |ref| enqueue(ref) }
    download_enqueued
  end

  def repository_url(*args)
    File.join(repository.external_url, *args)
  end

  def repository_path
  end

  def parse_release_file(file_ref)
    metadata_references = []
    found = false
    File.foreach(file_ref.local_path, chomp: true) do |line|
      if line == 'SHA256:'
        # example: b8a41cf82b68c2576c45e92e4fd7d194144794eaa06b55d52691f5255fa9a4b0 2604 Packages
        found = true
      end
      next unless found

      file_details = line.match(/^\s([a-z0-9]{64})\s+(\d+)\s+(.+)$/)
      # FIXME: handle partially corrupted files
      next unless file_details

      config = {
        relative_path: file_details[3],
        base_dir: file_ref.base_dir,
        base_url: file_ref.base_url,
        cache_dir: file_ref.cache_dir
      }

      ref = RMT::Mirror::FileReference.new(**config)
      # The type is left as nil. We might need to look into this in the future
      ref.tap do |r|
        r.checksum = file_details[1]
        r.checksum_type = 'SHA256'
        r.size = file_details[2].to_i
        r.type = nil
      end

      metadata_references.append(ref)
    end
    metadata_references
  end

end
