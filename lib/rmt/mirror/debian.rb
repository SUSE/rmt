class RMT::Mirror::Debian < RMT::Mirror::Base
  RELEASE_FILE_NAME = 'Release'.freeze
  SIGNATURE_FILE_NAME = 'Release.gpg'.freeze
  KEY_FILE_NAME = 'Release.key'.freeze
  INRELEASE_FILE_NAME = 'InRelease'.freeze
  NESTED_REPOSITORY_REGEX = %r{/dists/.*/$}.freeze


  def mirror_implementation
    create_repository_path
    create_temp_dir(:metadata)

    updated_metadata_files = mirror_metadata
    mirror_packages(updated_metadata_files)

    # We can not simply move the whole directory here, since there a
    glob_metadata = File.join(temp(:metadata), '*')
    move_files(glob: glob_metadata, destination: repository_path)
  end

  def mirror_metadata
    @logger.debug _('Mirroring metadata files')
    release = download_cached!(RELEASE_FILE_NAME, to: temp(:metadata))

    key = file_reference(KEY_FILE_NAME, to: temp(:metadata))
    signature = file_reference(SIGNATURE_FILE_NAME, to: temp(:metadata))
    inrelease = file_reference(INRELEASE_FILE_NAME, to: temp(:metadata))

    check_signature(key_file: key, signature_file: signature, metadata_file: release)

    metadata_refs = parse_release_file(release)
    # We need to make sure downloading the InRelease file which is not referenced
    # anywhere
    metadata_refs << inrelease

    # The nested debian structure only contains the zipped version of packages sometimes
    # However, the release file still contains a reference to the unzipped versions
    # So, we don't error if they don't exist
    packages_metadata, optional_metadata = metadata_refs.partition { |ref| is_mandatory? ref }

    # fail early if required Packages.gz files are missing
    enqueue(packages_metadata)
    download_enqueued

    enqueue(optional_metadata)
    download_enqueued(continue_on_error: true)

    # If revalidate_repodata is turned off, only return changed metadata files
    if RMT::Config.revalidate_repodata?
      metadata_refs
    else
      metadata_refs.select { |m| metadata_updated?(m) }
    end
  end

  def mirror_packages(metadata_refs)
    packagelists = metadata_refs.select { |ref| File.basename(ref.local_path) == 'Packages.gz' }

    packagelists.each do |packagelist|
      parse_package_list(packagelist).each do |ref|
        enqueue(ref) if need_to_download?(ref)
      end
    end

    @logger.debug _('Mirroring packages')
    download_enqueued
  end

  def parse_package_list(packagelist)
    @logger.debug "Extracting package list from metadata file #{packagelist.local_path}"
    packages = []
    hdl = File.open(packagelist.local_path, 'rb')

    current = {}
    Zlib::GzipReader.new(hdl).each_line do |line|
      if line == "\n"
        ref = file_reference(current[:filename], to: repository_path)
        ref.arch = current[:architecture]
        ref.checksum = current[:sha256]
        ref.checksum_type = 'SHA256'
        ref.size = current[:size].to_i
        ref.type = :deb

        # In a nested debian repository stucture, the metadata and packages are stored in different locations
        # so we need to update the base_url if we encounter the nested structure
        # We assume that if the base_url contains '/dists/', it's a nested debian structure
        if ref.base_url.match?(NESTED_REPOSITORY_REGEX)
          ref.tap do |r|
            r.base_url.sub!(NESTED_REPOSITORY_REGEX, '/')
            r.base_dir.sub!(NESTED_REPOSITORY_REGEX, '/')
            r.cache_dir.sub!(NESTED_REPOSITORY_REGEX, '/')
          end
        end

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
    message = _("Could not read '%{file}': %{error}" % { file: packagelist.local_path, error: e })
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

  def is_mandatory?(file_ref)
    # This check is needed to separate what files are mandatory to download
    # We expect only Packages.gz to always be present
    File.basename(file_ref.relative_path) == 'Packages.gz'
  end
end
