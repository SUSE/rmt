require 'rmt/downloader'
require 'rmt/rpm'
require 'time'

# rubocop:disable Metrics/ClassLength
class RMT::Mirror

  class RMT::Mirror::Exception < RuntimeError
  end

  def initialize(mirroring_base_dir:, repository_url:, local_path:, mirror_src: false, auth_token: nil, logger: nil, to_offline: false)
    @repository_dir = File.join(mirroring_base_dir, local_path)
    @repository_url = repository_url
    @mirror_src = mirror_src
    @logger = logger || Logger.new('/dev/null')
    @primary_files = []
    @deltainfo_files = []
    @auth_token = auth_token
    @force_dedup_by_copy = to_offline

    @downloader = RMT::Downloader.new(
      repository_url: @repository_url,
      destination_dir: @repository_dir,
      logger: @logger,
      save_for_dedup: !to_offline # don't save files for deduplication when in offline mode
    )
  end

  def mirror
    create_directories
    mirror_license
    # downloading license doesn't require an auth token
    @downloader.auth_token = @auth_token
    mirror_metadata
    mirror_data

    replace_directory(File.join(@temp_metadata_dir, 'repodata'), File.join(@repository_dir, 'repodata'))
    replace_directory(@temp_licenses_dir, File.join(@repository_dir, '../product.license/'))
  end

  def self.from_uri(uri, auth_token, repository_url: nil, base_dir: nil, to_offline: false)
    repository_url ||= uri

    new(
      mirroring_base_dir: base_dir || RMT::DEFAULT_MIRROR_DIR,
      repository_url: uri,
      auth_token: auth_token,
      local_path: Repository.make_local_path(repository_url),
      mirror_src: Settings.mirroring.mirror_src,
      logger: Logger.new(STDOUT),
      to_offline: to_offline
    )
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

    begin
      local_filename = @downloader.download('repodata/repomd.xml')
    rescue RMT::Downloader::Exception => e
      raise RMT::Mirror::Exception.new("Repodata download failed: #{e}")
    end

    begin
      @downloader.download('repodata/repomd.xml.key')
      @downloader.download('repodata/repomd.xml.asc')
    rescue RMT::Downloader::Exception
      @logger.info('Repository metadata signatures are missing')
    end

    begin
      repomd_parser = RMT::Rpm::RepomdXmlParser.new(local_filename)
      repomd_parser.parse

      repomd_parser.referenced_files.each do |reference|
        @downloader.download(
          reference.location,
            checksum_type: reference.checksum_type,
            checksum_value: reference.checksum
        )
        @primary_files << reference.location if (reference.type == :primary)
        @deltainfo_files << reference.location if (reference.type == :deltainfo)
      end
    rescue RuntimeError => e
      FileUtils.remove_entry(@temp_metadata_dir)
      raise RMT::Mirror::Exception.new("Error while mirroring metadata files: #{e}")
    rescue Interrupt => e
      FileUtils.remove_entry(@temp_metadata_dir)
      raise e
    end
  end

  def mirror_license
    @downloader.repository_url = URI.join(@repository_url, '../product.license/')
    @downloader.destination_dir = @temp_licenses_dir
    @downloader.cache_dir = File.join(@repository_dir, '../product.license/')

    begin
      directory_yast = @downloader.download('directory.yast')
    rescue RMT::Downloader::Exception
      @logger.info('No product license found')
      return
    end

    begin
      File.open(directory_yast).each_line do |filename|
        filename.strip!
        next if filename == 'directory.yast'
        @downloader.download(filename)
      end
    rescue RMT::Downloader::Exception => e
      FileUtils.remove_entry(@temp_licenses_dir)
      @temp_licenses_dir = nil
      raise RMT::Mirror::Exception.new("Error during mirroring metadata: #{e.message}")
    end
  end

  def mirror_data
    @downloader.repository_url = @repository_url
    @downloader.destination_dir = @repository_dir
    @downloader.cache_dir = nil

    @deltainfo_files.each do |filename|
      parser = RMT::Rpm::DeltainfoXmlParser.new(
        File.join(@temp_metadata_dir, filename),
        @mirror_src
      )
      parser.parse
      to_download = parsed_files_after_dedup(@repository_dir, parser.referenced_files)
      @downloader.download_multi(to_download) unless to_download.empty?
    end

    @primary_files.each do |filename|
      parser = RMT::Rpm::PrimaryXmlParser.new(
        File.join(@temp_metadata_dir, filename),
        @mirror_src
      )
      parser.parse
      to_download = parsed_files_after_dedup(@repository_dir, parser.referenced_files)
      @downloader.download_multi(to_download) unless to_download.empty?
    end
  end

  private

  def replace_directory(source_dir, destination_dir)
    old_directory = File.join(File.dirname(destination_dir), '.old_' + File.basename(destination_dir))

    FileUtils.remove_entry(old_directory) if Dir.exist?(old_directory)
    FileUtils.mv(destination_dir, old_directory) if Dir.exist?(destination_dir)
    FileUtils.mv(source_dir, destination_dir)
  ensure
    FileUtils.remove_entry(source_dir) if Dir.exist?(source_dir)
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

end
