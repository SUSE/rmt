class RMT::Mirror::Repomd < RMT::Mirror::Base
  # include RMT::Deduplicator
  include RMT::FileValidator

  def set_auth_token(token)
    downloader.auth_token = token
  end

  def without_auth
    token = downloader.auth_token
    yield
    downloader.auth_token = token
  end

  def mirror_licenses
    without_auth do
      # https://.../product.licenses/directory.yast
      diryast = RMT::Mirror::FileReference.new(
        relative_path: 'directory.yast',
        base_dir: temp(:licenses),
        base_url: repository_url.chomp('/') + '.licenses',
        cache_dir: repository_path.chomp('/') + '.licenses'
      )

      downloader.download_multi([diryast])
      licences = parse_yast_directory(diryast)
      licences.each { |lic| enqueue(lic) }
    end

    download_enqueued!
  end

  def parse_repomd_xml(repomd)
    references = RepomdParser::RepomdXmlParser.new(repomd.local_path).parse

    references.map do |meta|
      paths = {
        base_dir: repomd.base_dir,
        base_url: repomd.base_url,
        cache_dir: repomd.cache_dir
      }
      RMT::Mirror::FileReference.build_from_metadata(meta, **paths)
    end
  end

  def mirror_metadata
    repomd_xml = download_cached!('repodata/repomd.xml', to: temp(:metadata))

    # optional do
    #   signature = download_cached!('repodata/repomd.xml.asc', to: temp(:metadata))
    #   key = download_cached!('repodata/repomd.xml.key', to: temp(:metadata))
    #   repomd_xml.verify_signature(key: key, signature: signature)
    # end
    
    metadata = parse_repomd_xml(repomd_xml)
    metadata.each { |ref| enqueue ref }

    download_enqueued

    metadata
  end

  def mirror_packages(metadata)
    paths = {
      base_dir: repository_dir,
      base_url: repository_url,
      cache_dir: nil
    }
    # FIXME: Support deltainfo files
    sources = metadata.select { |src| [:primary].include?(src.type) }
   
    sources.each do |src|
      packages = case src.type
                 when :primary then RepomdParser::PrimaryXmlParser
                 when :deltainfo then RepomdParser::DeltainfoXmlParser
                 end.new(src.local_path).parse

      packages.each do |meta|
        ref = RMT::Mirror::FileReference.build_from_metadata(meta, **paths)

        next if ref.arch == 'src' && !mirror_sources
        next if validate_local_file(ref)
        # FIXME: Deduplicate if possible
        enqueue ref
      end
    end

    download_enqueued
  end

  def mirror_with_implementation!
    create_temp :licenses, :metadata
    create_dir repository_dir

    optional _('mirroring SUSE licenses') do
      mirror_licenses
    end

    metadata = mirror_metadata
    mirror_packages(metadata)

    #replace_directory(Dir.join(temp(:licenses), 'licenses'), dest: repository_path('.licenses/')) if licenses
    move_dir(source: File.join(temp(:metadata), 'repodata'), dest: repository_path('repodata'))
  end

  def parse_yast_directory(diryast)

  end
end
