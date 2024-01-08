require 'rmt/downloader'
require 'rmt/gpg'
require 'repomd_parser'
require 'time'

class RMT::Mirror::Repomd < RMT::Mirror::Base

  def mirror_implementation
    create_temp_dir(:license)
    create_temp_dir(:metadata)
    licenses = RMT::Mirror::License.new(repository: repository, logger: logger, mirroring_base_dir: mirroring_base_dir)
    licenses.mirror

    metadata_files = mirror_metadata
    # mirror_packages(metadata_files, repository_dir, repository_url)

    # # FIXME: Ensure license dirs are not created if the repository doesn't contain them
    # replace_directory(temp(:license), repository_dir.chomp('/') + '.license/') if Dir.exist?(temp(:license))
    # replace_directory(File.join(temp(:metadata), 'repodata'), File.join(repository_dir, 'repodata'))
  end

  protected

  def mirror_metadata
    repomd_xml = download_cached!('repodata/repomd.xml', to: temp(:metadata))
    signature_file = file_reference('repodata/repomd.xml.asc', to: temp(:metadata))
    key_file = file_reference('repodata/repomd.xml.key', to: temp(:metadata))
    check_signature(key_file: key_file, signature_file: signature_file, metadata_file: repomd_xml)

    metadata_files = RepomdParser::RepomdXmlParser.new(repomd_xml.local_path).parse
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

  def mirror_packages(metadata_files, repository_dir, repository_url)
    package_references = parse_packages_metadata(metadata_files)

    package_file_references = package_references.map do |reference|
      RMT::Mirror::FileReference.build_from_metadata(reference,
                                                     base_dir: repository_dir,
                                                     base_url: repository_url)
    end

    failed_downloads = download_package_files(package_file_references)

    raise _('Failed to download %{failed_count} files') % { failed_count: failed_downloads.size } unless failed_downloads.empty?
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring packages: %{error}') % { error: e.message })
  end

  def parse_packages_metadata(metadata_references)
    xml_parsers = { deltainfo: RepomdParser::DeltainfoXmlParser,
                    primary: RepomdParser::PrimaryXmlParser }

    metadata_references
      .map { |file| xml_parsers[file.type]&.new(file.local_path) }.compact
      .map(&:parse).flatten
  end

  def download_package_files(file_references)
    files_to_download = file_references.select { |file| need_to_download?(file) }
    return [] if files_to_download.empty?

    downloader.download_multi(files_to_download, ignore_errors: true)
  end

end
