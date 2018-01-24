require 'rmt/downloader'
require 'rmt/rpm'

class RMT::Mirror

  class RMT::Mirror::Exception < RuntimeError
  end

  def initialize(mirroring_base_dir:, repository_url:, local_path:, mirror_src: false, auth_token: nil, logger: nil, deduplication_enabled: true)
    @mirroring_base_dir = mirroring_base_dir
    @repository_url = repository_url
    @local_path = local_path
    @mirror_src = mirror_src
    @logger = logger || Logger.new('/dev/null')
    @primary_files = []
    @deltainfo_files = []
    @auth_token = auth_token
    @deduplication_enabled = deduplication_enabled

    @downloader = RMT::Downloader.new(
      repository_url: @repository_url,
      local_path: @repodata_dir.to_s,
      logger: @logger
    )
  end

  def mirror
    create_directories
    mirror_license
    # downloading license doesn't require an auth token
    @downloader.auth_token = @auth_token
    mirror_metadata
    mirror_data
    replace_metadata
  end

  def self.from_url(repository_url, auth_token, base_dir: nil, deduplication_enabled: false)
    new(
      mirroring_base_dir: base_dir || RMT::DEFAULT_MIRROR_DIR,
      repository_url: repository_url,
      auth_token: auth_token,
      local_path: Repository.make_local_path(repository_url),
      mirror_src: Settings.mirroring.mirror_src,
      logger: Logger.new(STDOUT),
      deduplication_enabled: deduplication_enabled
    )
  end

  def self.from_repo_model(repository, base_dir: nil, deduplication_enabled: true)
    new(
      mirroring_base_dir: base_dir || RMT::DEFAULT_MIRROR_DIR,
      repository_url: repository.external_url,
      local_path: repository.local_path,
      auth_token: repository.auth_token,
      mirror_src: Settings.mirroring.mirror_src,
      logger: Logger.new(STDOUT),
      deduplication_enabled: deduplication_enabled
    )
  end

  protected

  def create_directories
    begin
      local_repo_dir = File.join(@mirroring_base_dir, @local_path)
      FileUtils.mkpath(local_repo_dir) unless Dir.exist?(local_repo_dir)
    rescue StandardError => e
      raise RMT::Mirror::Exception.new("Can not create a local repository directory: #{e}")
    end

    begin
      @repodata_dir = Dir.mktmpdir
    rescue StandardError => e
      raise RMT::Mirror::Exception.new("Can not create a temporary directory: #{e}")
    end
  end

  def mirror_metadata
    @downloader.repository_url = URI.join(@repository_url)
    @downloader.local_path = File.join(@repodata_dir.to_s)

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
        @downloader.download(reference.location, reference.checksum_type, reference.checksum)
        @primary_files << reference.location if (reference.type == :primary)
        @deltainfo_files << reference.location if (reference.type == :deltainfo)
      end
    rescue RuntimeError => e
      FileUtils.remove_entry(@repodata_dir)
      raise RMT::Mirror::Exception.new("Error while mirroring metadata files: #{e}")
    rescue Interrupt => e
      FileUtils.remove_entry(@repodata_dir)
      raise e
    end
  end

  def mirror_license
    @downloader.repository_url = URI.join(@repository_url, '../product.license/')
    @downloader.local_path = File.join(@mirroring_base_dir, @local_path, '../product.license/')

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
      raise RMT::Mirror::Exception.new("Error during mirroring metadata: #{e.message}")
    end
  end

  def mirror_data
    root_path = File.join(@mirroring_base_dir, @local_path)
    @downloader.repository_url = @repository_url
    @downloader.local_path = root_path

    @deltainfo_files.each do |filename|
      parser = RMT::Rpm::DeltainfoXmlParser.new(
        File.join(@repodata_dir, filename),
        @mirror_src
      )
      parser.parse
      to_download = parsed_files_after_dedup(root_path, parser.referenced_files)
      @downloader.download_multi(to_download) unless to_download.empty?
    end

    @primary_files.each do |filename|
      parser = RMT::Rpm::PrimaryXmlParser.new(
        File.join(@repodata_dir, filename),
        @mirror_src
      )
      parser.parse
      to_download = parsed_files_after_dedup(root_path, parser.referenced_files)
      @downloader.download_multi(to_download) unless to_download.empty?
    end
  end

  def replace_metadata
    local_repo_dir = File.join(@mirroring_base_dir, @local_path)
    old_repodata = File.join(local_repo_dir, '.old_repodata')
    repodata = File.join(local_repo_dir, 'repodata')
    new_repodata = File.join(@repodata_dir.to_s, 'repodata')

    FileUtils.remove_entry(old_repodata) if Dir.exist?(old_repodata)
    FileUtils.mv(repodata, old_repodata) if Dir.exist?(repodata)
    FileUtils.mv(new_repodata, repodata)
  ensure
    FileUtils.remove_entry(@repodata_dir)
  end

  private

  def deduplicate(checksum_type, checksum_value, destination)
    return false unless @deduplication_enabled
    return false unless ::RMT::Deduplicator.deduplicate(checksum_type, checksum_value, destination)
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
