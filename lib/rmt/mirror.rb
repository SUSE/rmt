require 'rmt/downloader'
require 'rmt/gpg'
require 'repomd_parser'
require 'time'

class RMT::Mirror
  class RMT::Mirror::Exception < RuntimeError
  end

  def initialize(mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR, logger:, mirror_src: false, airgap_mode: false)
    @mirroring_base_dir = mirroring_base_dir
    @mirror_src = mirror_src
    @logger = logger
    @force_dedup_by_copy = airgap_mode

    @downloader = RMT::Downloader.new(
      repository_url: @repository_url,
      destination_dir: @repository_dir,
      logger: @logger,
      save_for_dedup: !airgap_mode # don't save files for deduplication when in offline mode
    )
  end

  def mirror_suma_product_tree(repository_url:)
    # we have an inconsistency in how we mirror in offline mode
    # in normal mode we mirror in the following way:
    # base_dir/repo/...
    # however, in offline mode we mirror in the following way
    # base_dir/...
    # we need this extra step to ensure that we write to the public directory
    base_dir = @mirroring_base_dir
    base_dir = File.expand_path(File.join(@mirroring_base_dir, '/../')) if @mirroring_base_dir == RMT::DEFAULT_MIRROR_DIR

    @repository_dir = File.join(base_dir, '/suma/')
    @downloader.repository_url = URI.join(repository_url)
    @downloader.destination_dir = @repository_dir
    @downloader.cache_dir = @repository_dir

    @logger.info _('Mirroring SUSE Manager product tree to %{dir}') % { dir: @repository_dir }
    @downloader.download('product_tree.json')
  rescue RMT::Downloader::Exception => e
    raise RMT::Mirror::Exception.new(_('Could not mirror SUSE Manager product tree with error: %{error}') % { error: e.message })
  end

  def mirror(repository_url:, local_path:, auth_token: nil, repo_name: nil)
    @repository_dir = File.join(@mirroring_base_dir, local_path)
    @repository_url = repository_url

    @logger.info _('Mirroring repository %{repo} to %{dir}') % { repo: repo_name || repository_url, dir: @repository_dir }

    create_directories
    mirror_license
    # downloading license doesn't require an auth token
    @downloader.auth_token = auth_token
    primary_files, deltainfo_files = mirror_metadata
    mirror_data(primary_files, deltainfo_files)

    replace_directory(@temp_licenses_dir, @repository_dir.chomp('/') + '.license/') if Dir.exist?(@temp_licenses_dir)
    replace_directory(File.join(@temp_metadata_dir, 'repodata'), File.join(@repository_dir, 'repodata'))
  ensure
    remove_tmp_directories
  end

  protected

  def create_directories
    begin
      FileUtils.mkpath(@repository_dir) unless Dir.exist?(@repository_dir)
    rescue StandardError => e
      raise RMT::Mirror::Exception.new(_('Could not create local directory %{dir} with error: %{error}') % { dir: @repository_dir, error: e.message })
    end

    begin
      @temp_licenses_dir = Dir.mktmpdir
      @temp_metadata_dir = Dir.mktmpdir
    rescue StandardError => e
      raise RMT::Mirror::Exception.new(_('Could not create a temporary directory: %{error}') % { error: e.message })
    end
  end

  def mirror_metadata
    @downloader.repository_url = URI.join(@repository_url)
    @downloader.destination_dir = @temp_metadata_dir
    @downloader.cache_dir = @repository_dir

    local_filename = @downloader.download('repodata/repomd.xml')

    begin
      signature_file = @downloader.download('repodata/repomd.xml.asc')
      key_file       = @downloader.download('repodata/repomd.xml.key')

      RMT::GPG.new(
        metadata_file: local_filename, key_file: key_file, signature_file: signature_file, logger: @logger
      ).verify_signature
    rescue RMT::Downloader::Exception => e
      if (e.http_code == 404)
        @logger.info(_('Repository metadata signatures are missing'))
      else
        raise(_('Failed to get repository metadata signatures with HTTP code %{http_code}') % { http_code: e.http_code })
      end
    end

    metadata_files = RepomdParser::RepomdXmlParser.new(local_filename).parse
    primary_files = metadata_files.select { |reference| reference.type == :primary }
    deltainfo_files = metadata_files.select { |reference| reference.type == :deltainfo }

    @downloader.download_multi(metadata_files)

    [primary_files, deltainfo_files]
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring metadata: %{error}') % { error: e.message })
  end

  def mirror_license
    @downloader.repository_url = @repository_url.chomp('/') + '.license/'
    @downloader.destination_dir = @temp_licenses_dir
    @downloader.cache_dir = @repository_dir.chomp('/') + '.license/'

    begin
      directory_yast = @downloader.download('directory.yast')
    rescue RMT::Downloader::Exception
      FileUtils.remove_entry(@temp_licenses_dir) # the repository would have an empty licenses directory unless removed
      return
    end

    license_files = File.readlines(directory_yast).map(&:strip).reject { |item| item == 'directory.yast' }
    @downloader.download_multi(license_files)
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring license: %{error}') % { error: e.message })
  end

  def mirror_data(primary_files, deltainfo_files)
    @downloader.repository_url = @repository_url
    @downloader.destination_dir = @repository_dir
    @downloader.cache_dir = nil

    package_files =
      parse_mirror_data_files(deltainfo_files, RepomdParser::DeltainfoXmlParser) +
      parse_mirror_data_files(primary_files, RepomdParser::PrimaryXmlParser)
    failed_downloads = download_package_files(package_files)

    raise _('Failed to download %{failed_count} files') % { failed_count: failed_downloads.size } unless failed_downloads.empty?
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring data: %{error}') % { error: e.message })
  end

  def parse_mirror_data_files(references, xml_parser_class)
    references.map do |reference|
      xml_parser_class.new(File.join(@temp_metadata_dir, reference.location)).parse
    end.flatten
  end

  def download_package_files(package_references)
    packages_to_download = filter_eligible_packages(package_references)
    return [] if packages_to_download.empty?
    @downloader.download_multi(packages_to_download, ignore_errors: true)
  end

  def filter_eligible_packages(package_references)
    parsed_files = package_references.reject do |package|
      package.arch == 'src' && !@mirror_src
    end
    parsed_files_after_dedup(@repository_dir, parsed_files)
  end

  def replace_directory(source_dir, destination_dir)
    old_directory = File.join(File.dirname(destination_dir), '.old_' + File.basename(destination_dir))

    FileUtils.remove_entry(old_directory) if Dir.exist?(old_directory)
    FileUtils.mv(destination_dir, old_directory) if Dir.exist?(destination_dir)
    FileUtils.mv(source_dir, destination_dir)
    FileUtils.chmod(0o755, destination_dir)
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while moving directory %{src} to %{dest}: %{error}') % {
      src: source_dir,
      dest: destination_dir,
      error: e.message
    })
  end

  def deduplicate(checksum_type, checksum_value, destination)
    return false unless ::RMT::Deduplicator.deduplicate(checksum_type, checksum_value, destination, force_copy: @force_dedup_by_copy)
    @logger.info("→ #{File.basename(destination)}")
    true
  rescue ::RMT::Deduplicator::MismatchException => e
    @logger.debug(_('× File does not exist or has wrong filesize, deduplication ignored %{error}.') % { error: e.message })
    false
  end

  def parsed_files_after_dedup(root_path, referenced_files)
    files = referenced_files.map do |parsed_file|
      local_file = ::RMT::Downloader.make_local_path(root_path, parsed_file.location)
      unless File.exist?(local_file) || deduplicate(parsed_file.checksum_type, parsed_file.checksum, local_file)
        parsed_file
      end
    end
    files.compact
  end

  def remove_tmp_directories
    FileUtils.remove_entry(@temp_licenses_dir) if @temp_licenses_dir && Dir.exist?(@temp_licenses_dir)
    FileUtils.remove_entry(@temp_metadata_dir) if @temp_metadata_dir && Dir.exist?(@temp_metadata_dir)
  end

end
