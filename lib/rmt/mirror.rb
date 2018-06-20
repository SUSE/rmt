require 'rmt/downloader'
require 'rmt/rpm'
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

  def mirror(repository_url:, local_path:, auth_token: nil, repo_name: nil)
    @repository_dir = File.join(@mirroring_base_dir, local_path)
    @repository_url = repository_url

    @logger.info "Mirroring repository #{repo_name || repository_url} to #{@repository_dir}"

    create_directories
    mirror_license
    # downloading license doesn't require an auth token
    @downloader.auth_token = auth_token
    primary_files, deltainfo_files = mirror_metadata
    mirror_data(primary_files, deltainfo_files)

    replace_directory(@temp_licenses_dir, File.join(@repository_dir, '../product.license/')) if Dir.exist?(@temp_licenses_dir)
    replace_directory(File.join(@temp_metadata_dir, 'repodata'), File.join(@repository_dir, 'repodata'))
  ensure
    remove_tmp_directories
  end

  protected

  def create_directories
    begin
      FileUtils.mkpath(@repository_dir) unless Dir.exist?(@repository_dir)
    rescue StandardError => e
      raise RMT::Mirror::Exception.new("Can not create a local repository directory: #{e}")
    end

    begin
      @temp_licenses_dir = Dir.mktmpdir
      @temp_metadata_dir = Dir.mktmpdir
    rescue StandardError => e
      raise RMT::Mirror::Exception.new("Can not create a temporary directory: #{e}")
    end
  end

  def mirror_metadata
    @downloader.repository_url = URI.join(@repository_url)
    @downloader.destination_dir = @temp_metadata_dir
    @downloader.cache_dir = @repository_dir

    local_filename = @downloader.download('repodata/repomd.xml')

    begin
      @downloader.download('repodata/repomd.xml.key')
      @downloader.download('repodata/repomd.xml.asc')
    rescue RMT::Downloader::Exception
      @logger.info('Repository metadata signatures are missing')
    end

    primary_files = []
    deltainfo_files = []

    repomd_parser = RMT::Rpm::RepomdXmlParser.new(local_filename)
    repomd_parser.parse

    repomd_parser.referenced_files.each do |reference|
      @downloader.download(
        reference.location,
          checksum_type: reference.checksum_type,
          checksum_value: reference.checksum
      )
      primary_files << reference.location if (reference.type == :primary)
      deltainfo_files << reference.location if (reference.type == :deltainfo)
    end

    [primary_files, deltainfo_files]
  rescue StandardError => e
    raise RMT::Mirror::Exception.new("Error while mirroring metadata: #{e}")
  end

  def mirror_license
    @downloader.repository_url = URI.join(@repository_url, '../product.license/')
    @downloader.destination_dir = @temp_licenses_dir
    @downloader.cache_dir = File.join(@repository_dir, '../product.license/')

    begin
      directory_yast = @downloader.download('directory.yast')
    rescue RMT::Downloader::Exception
      FileUtils.remove_entry(@temp_licenses_dir) # the repository would have an empty licenses directory unless removed
      @logger.info('No product license found')
      return
    end

    File.open(directory_yast).each_line do |filename|
      filename.strip!
      next if filename == 'directory.yast'
      @downloader.download(filename)
    end
  rescue StandardError => e
    raise RMT::Mirror::Exception.new("Error while mirroring license: #{e.message}")
  end

  def mirror_data(primary_files, deltainfo_files)
    @downloader.repository_url = @repository_url
    @downloader.destination_dir = @repository_dir
    @downloader.cache_dir = nil

    deltainfo_files.each do |filename|
      parser = RMT::Rpm::DeltainfoXmlParser.new(
        File.join(@temp_metadata_dir, filename),
        @mirror_src
      )
      parser.parse
      to_download = parsed_files_after_dedup(@repository_dir, parser.referenced_files)
      @downloader.download_multi(to_download) unless to_download.empty?
    end

    primary_files.each do |filename|
      parser = RMT::Rpm::PrimaryXmlParser.new(
        File.join(@temp_metadata_dir, filename),
        @mirror_src
      )
      parser.parse
      to_download = parsed_files_after_dedup(@repository_dir, parser.referenced_files)
      @downloader.download_multi(to_download) unless to_download.empty?
    end
  rescue StandardError => e
    raise RMT::Mirror::Exception.new("Error while mirroring data: #{e}")
  end

  def replace_directory(source_dir, destination_dir)
    old_directory = File.join(File.dirname(destination_dir), '.old_' + File.basename(destination_dir))

    FileUtils.remove_entry(old_directory) if Dir.exist?(old_directory)
    FileUtils.mv(destination_dir, old_directory) if Dir.exist?(destination_dir)
    FileUtils.mv(source_dir, destination_dir)
  rescue StandardError => e
    raise RMT::Mirror::Exception.new("Error while moving directory #{source_dir} to #{destination_dir}: #{e}")
  end

  def deduplicate(checksum_type, checksum_value, destination)
    return false unless ::RMT::Deduplicator.deduplicate(checksum_type, checksum_value, destination, force_copy: @force_dedup_by_copy)
    @logger.info("→ #{File.basename(destination)}")
    true
  rescue ::RMT::Deduplicator::MismatchException => e
    @logger.debug("× File does not exist or has wrong filesize, deduplication ignored #{e.message}.")
    false
  end

  def parsed_files_after_dedup(root_path, referenced_files)
    files = referenced_files.map do |parsed_file|
      local_file = ::RMT::Downloader.make_local_path(root_path, parsed_file.location)
      if File.exist?(local_file) || deduplicate(parsed_file[:checksum_type], parsed_file[:checksum], local_file)
        nil
      else
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
