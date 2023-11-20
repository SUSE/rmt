class RMT::Mirror::Repomd < RMT::Mirror::Base
  include RMT::Deduplicator
  include RMT::FileValidator

  def mirror_with_implementation!
    create_temp :licenses, :metadata
    set_auth_token auth_token

    create_dir local_repository_path

    # 1. Licenses
    optional do
      without_auth do
        diryast = download_cached!('.licenses/directory.yast', to: temp(:licences))
        licences = parse_yast_directory(diryast)
        licences.each { |lic| enqueue(lic) }
      end
    end

    download_enqueued!

    # 2. Metadata
    repomd_xml = download_cached!('repodata/repomd.xml', to: temp(:metadata))

    optional do
      signature = download_cached!('repodata/repomd.xml.asc', to: temp(:metadata))
      key = download_cached!('repodata/repomd.xml.key', to: temp(:metadata))
      repomd_xml.verify_signature(key: key, signature: signature)
    end

    repomd = parse_repomd_xml(repomd_xml)
    repomd.each { |meta| enqueue(meta) }

    download_enqueued!

    # 3. Packages
    sources = repomd.select { |ref| ref.type.include?(:deltainfo, :primary) }
    sources.each do |source|
      packages = case source.type
                 when :primary then RepomdParser::PrimaryXmlParser
                 when :deltainfo then RepomdParser::DeltainfoXmlParser
                 end.parse(source.content)

      packages.each do |pkg|
        next unless pkg.source_type? && mirror_package_sources
        next if pkg.uptodate?
        next if deduplicate(pkg)
        enqueue(pkg)
      end
    end

    download_enqueued!

    replace_directory(temp(:licences), repository_path('.licences/')) if licenses
    replace_directory(temp(:metadata), repository_path('repodata'))
  end
end
