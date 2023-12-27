class RMT::Mirror::Debian < RMT::Mirror::Base
  RELEASE_FILE_NAME = 'Release'.freeze
  GPG_FILE_NAME = 'Release.gpg'.freeze
  KEY_FILE_NAME = 'Release.key'.freeze
  INRELEASE_FILE_NAME = 'InRelease'.freeze

  def mirror_implementation
    create_temp_dir(:metadata)
    sources = mirror_metadata
    mirror_packages(sources)
  end

  def mirror_metadata
    release = download_cached!(repository_url(RELEASE_FILE_NAME), to: temp(:metadata))
    key = file_reference(repository_url(GPG_FILE_NAME), to: temp(:metadata))
    signature = file_reference(repository_url(KEY_FILE_NAME), to: temp(:metadata))
    inrelease = file_reference(repository_url(INRELEASE_FILE_NAME), to: temp(:metadata))

    check_signature(key_file: key, signature_file: signature, metadata_file: release)

    metadata_refs = parse_release_file(release)
    # We need to make sure downloading the InRelease file which is not referenced
    # anywhere
    metadata_refs << inrelease
    metadata_refs.each { |ref| enqueue(ref) }

    download_enqueued
    metadata_refs
  end

  def mirror_packages(metadata_refs)
    packagelists = metadata_refs.select { |ref| File.basename(ref.local_path) == 'Packages.gz' }

    packagelists.each do |list|
      parse_package_list(list).each { |pkg| enqueue pkg }
    end

    download_enqueued
  end

  def parse_package_list(list)
    packages = []
    hdl = File.open(list.local_path, 'rb')

    current = {}
    Zlib::GzipReader.new(hdl).each_line do |line|
      if line == "\n"
        ref = file_reference(current[:filename], to: repository_path)
        ref.arch = current[:architecture]
        ref.checksum = current[:sha256]
        ref.checksum_type = 'SHA256'
        ref.size = current[:size].to_i
        ref.type = :deb

        packages << ref
        current = {}
      end

      # We do not care for multiline statements since we only interested in single line keys
      # Failing example:
      #   |Description: Command-line interface to Spacewalk and Red Hat Satellite servers|
      #   | spacecmd is a command-line interface to Spacewalk and Red Hat Satellite servers|
      #    ^--- it will be skipped here
      key, value = line.split(': ', 2)

      next if value.blank?

      current[key.downcase.to_sym] = value.strip
    end
    packages
  rescue Zlib::GzipFile::Error => e
    message = _("Could not read '%{file}': %{error}" % { file: list.local_path, error: e })
    raise RMT::Mirror::Exception.new(message)
  ensure
    hdl.close
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
