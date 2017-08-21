require 'rmt/downloader'
require 'rmt/rpm'

class RMT::Mirror

  class RMT::Mirror::Exception < RuntimeError; end

  def initialize(mirroring_base_dir:, repository_url:, local_path:, mirror_src: false, auth_token: nil, logger: nil)
    @mirroring_base_dir = mirroring_base_dir
    @repository_url = repository_url
    @local_path = local_path
    @mirror_src = mirror_src
    @logger = logger || Logger.new('/dev/null')
    @primary_files = []
    @deltainfo_files = []
    @auth_token = auth_token
  end

  def mirror
    mirror_metadata
    mirror_data
  end

  protected

  def mirror_metadata
    begin
      local_repo_dir = File.join(@mirroring_base_dir, @local_path)
      FileUtils.mkpath(local_repo_dir) unless Dir.exist?(local_repo_dir)
    rescue StandardError => e
      raise RMT::Mirror::Exception.new("Can not create a local repository directory: #{e}")
    end

    begin
      temp_dir = Dir.mktmpdir
    rescue StandardError => e
      raise RMT::Mirror::Exception.new("Can not create a temporary directory: #{e}")
    end

    @downloader = RMT::Downloader.new(
      repository_url: @repository_url,
      local_path: temp_dir.to_s,
      logger: @logger,
      auth_token: @auth_token
    )

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

      old_repodata = File.join(local_repo_dir, '.old_repodata')
      repodata = File.join(local_repo_dir, 'repodata')
      new_repodata = File.join(temp_dir.to_s, 'repodata')

      FileUtils.remove_entry(old_repodata) if Dir.exist?(old_repodata)
      FileUtils.mv(repodata, old_repodata) if Dir.exist?(repodata)
      FileUtils.mv(new_repodata, repodata)
    ensure
      FileUtils.remove_entry(temp_dir)
    end
  end

  def mirror_data
    @downloader.local_path = File.join(@mirroring_base_dir, @local_path)

    @deltainfo_files.each do |filename|
      parser = RMT::Rpm::DeltainfoXmlParser.new(
        File.join(@mirroring_base_dir, @local_path, filename),
        @mirror_src
      )
      parser.parse
      @downloader.download_multi(parser.referenced_files)
    end

    @primary_files.each do |filename|
      parser = RMT::Rpm::PrimaryXmlParser.new(
        File.join(@mirroring_base_dir, @local_path, filename),
        @mirror_src
      )
      parser.parse
      @downloader.download_multi(parser.referenced_files)
    end
  end

end
