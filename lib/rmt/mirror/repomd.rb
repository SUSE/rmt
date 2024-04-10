require 'rmt/downloader'
require 'rmt/gpg'
require 'repomd_parser'
require 'time'

class RMT::Mirror::Repomd < RMT::Mirror::Base

  def mirror_implementation
    create_repository_path
    create_temp_dir(:metadata)

    if repository_url.ends_with?('product')
      licenses = RMT::Mirror::License.new(repository: repository, logger: logger, mirroring_base_dir: mirroring_base_dir)
      licenses.mirror
    end

    metadata_files = mirror_metadata
    mirror_packages(metadata_files)

    replace_directory(source: File.join(temp(:metadata), 'repodata'), destination: repository_path('repodata'))
  end

  protected

  def mirror_metadata
    repomd_xml = download_cached!('repodata/repomd.xml', to: temp(:metadata))
    signature_file = file_reference('repodata/repomd.xml.asc', to: temp(:metadata))
    key_file = file_reference('repodata/repomd.xml.key', to: temp(:metadata))
    check_signature(key_file: key_file, signature_file: signature_file, metadata_file: repomd_xml)

    metadata_files = RepomdParser::RepomdXmlParser.new.parse_file(repomd_xml.local_path)
      .map do |reference|
        ref = RMT::Mirror::FileReference.build_from_metadata(reference, base_dir: temp(:metadata), base_url: repomd_xml.base_url)
        enqueue ref
        ref
      end

    download_enqueued

    metadata_files
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring metadata: %{error}') % { error: e.message })
  end

  def mirror_packages(metadata_references)
    package_references = parse_packages_metadata(metadata_references)

    packages = package_references.map do |reference|
      RMT::Mirror::FileReference.build_from_metadata(reference,
                                                     base_dir: repository_path,
                                                     base_url: repository_url)
    end

    packages.each do |package|
      enqueue package if need_to_download?(package)
    end

    failed = download_enqueued(continue_on_error: true)

    raise _('Failed to download %{failed_count} files') % { failed_count: failed.size } unless failed.empty?
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring packages: %{error}') % { error: e.message })
  end

  def parse_packages_metadata(metadata_references)
    xml_parsers = { deltainfo: RepomdParser::DeltainfoXmlParser,
                    primary: RepomdParser::PrimaryXmlParser }

    metadata_references.map do |file|
      next unless xml_parsers.key? file.type

      xml_parsers[file.type].new.parse_file(file.local_path)
    end.flatten.compact
  end
end
