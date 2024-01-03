require 'rmt/downloader'
require 'rmt/gpg'
require 'repomd_parser'
require 'time'

class RMT::Mirror::Repomd < RMT::Mirror::Base
  # def initialize(logger:, mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR, mirror_src: false, airgap_mode: false)
  #   @mirroring_base_dir = mirroring_base_dir
  #   @logger = logger
  #   @mirror_src = mirror_src
  #   @airgap_mode = airgap_mode
  #   @deep_verify = false

  #   # don't save files for deduplication when in offline mode
  #   @downloader = RMT::Downloader.new(logger: logger, track_files: !airgap_mode)
  # end

  def mirror_implementation
    create_temp_dir(:license)
    create_temp_dir(:metadata)
    mirror_license(repository_dir, repository_url, temp(:license))

    metadata_files = mirror_metadata(repository_dir, repository_url, temp(:metadata))
    mirror_packages(metadata_files, repository_dir, repository_url)

    # FIXME: Ensure license dirs are not created if the repository doesn't contain them
    replace_directory(temp(:license), repository_dir.chomp('/') + '.license/') if Dir.exist?(temp(:license))
    replace_directory(File.join(temp(:metadata), 'repodata'), File.join(repository_dir, 'repodata'))
  end

  protected

  def mirror_metadata(repository_dir, repository_url, temp_metadata_dir)
    mirroring_paths = {
      base_url: URI.join(repository_url),
      base_dir: temp_metadata_dir,
      cache_dir: repository_dir
    }

    repomd_xml = RMT::Mirror::FileReference.new(relative_path: 'repodata/repomd.xml', **mirroring_paths)
    downloader.download_multi([repomd_xml])

    begin
      signature_file = RMT::Mirror::FileReference.new(relative_path: 'repodata/repomd.xml.asc', **mirroring_paths)
      key_file       = RMT::Mirror::FileReference.new(relative_path: 'repodata/repomd.xml.key', **mirroring_paths)
      # mirror repomd.xml.asc first, because there are repos with repomd.xml.asc but without repomd.xml.key
      downloader.download_multi([signature_file])
      downloader.download_multi([key_file])

      RMT::GPG.new(
        metadata_file: repomd_xml.local_path,
        key_file: key_file.local_path,
        signature_file: signature_file.local_path,
        logger: logger
      ).verify_signature
    rescue RMT::Downloader::Exception => e
      if (e.http_code == 404)
        logger.info(_('Repository metadata signatures are missing'))
      else
        raise(_('Downloading repo signature/key failed with: %{message}, HTTP code %{http_code}') % { message: e.message, http_code: e.http_code })
      end
    end

    metadata_files = RepomdParser::RepomdXmlParser.new(repomd_xml.local_path).parse
      .map { |reference| RMT::Mirror::FileReference.build_from_metadata(reference, **mirroring_paths) }

    downloader.download_multi(metadata_files.dup)

    metadata_files
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring metadata: %{error}') % { error: e.message })
  end

  def mirror_license(repository_dir, repository_url, temp_licenses_dir)
    mirroring_paths = {
      base_url: repository_url.chomp('/') + '.license/',
      base_dir: temp_licenses_dir,
      cache_dir: repository_dir.chomp('/') + '.license/'
    }

    directory_yast = download_cached!('directory.yast', to: temp_licenses_dir)
    begin
      directory_yast = RMT::Mirror::FileReference.new(relative_path: 'directory.yast', **mirroring_paths)
      downloader.download_multi([directory_yast])
    rescue RMT::Downloader::Exception
      logger.debug("No license directory found for repository '#{repository_url}'")
      FileUtils.remove_entry(temp_licenses_dir) # the repository would have an empty licenses directory unless removed
      return
    end

    license_files = File.readlines(directory_yast.local_path)
      .map(&:strip).reject { |item| item == 'directory.yast' }
      .map { |relative_path| RMT::Mirror::FileReference.new(relative_path: relative_path, **mirroring_paths) }
    downloader.download_multi(license_files)
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring license files: %{error}') % { error: e.message })
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

  def need_to_download?(file)
    return false if file.arch == 'src' && !mirror_src
    return false if validate_local_file(file)
    return false if deduplicate(file)

    true
  end

  def replace_directory(source_dir, destination_dir)
    old_directory = File.join(File.dirname(destination_dir), '.old_' + File.basename(destination_dir))

    FileUtils.remove_entry(old_directory) if Dir.exist?(old_directory)
    FileUtils.mv(destination_dir, old_directory) if Dir.exist?(destination_dir)
    FileUtils.mv(source_dir, destination_dir, force: true)
    FileUtils.chmod(0o755, destination_dir)
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while moving directory %{src} to %{dest}: %{error}') % {
      src: source_dir,
      dest: destination_dir,
      error: e.message
    })
  end
end
