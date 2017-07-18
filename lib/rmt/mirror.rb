module RMT
end

class RMT::Mirror

  def initialize(mirroring_base_dir, repository_url, local_path, mirror_src = false, logger = nil)
    @mirroring_base_dir = mirroring_base_dir
    @repository_url = repository_url
    @local_path = local_path
    @mirror_src = mirror_src
    @logger = logger || Logger.new('/dev/null')
    @primary_files = []
    @deltainfo_files = []
  end

  def mirror
    mirror_metadata
    mirror_data
  end

  protected

  def mirror_metadata
    temp_dir = Dir.mktmpdir

    @downloader = RMT::Downloader.new(
      @repository_url,
      temp_dir.to_s,
      @logger
    )

    begin
      local_filename = @downloader.download('repodata/repomd.xml')
      rpmmd_parser = RMT::Rpm::Parser::RpmmdXml.new(local_filename)
      rpmmd_parser.parse

      rpmmd_parser.referenced_files.each do |reference|
        @downloader.download(reference.location, reference.checksum_type, reference.checksum)
        @primary_files << reference.location if (reference.type == :primary)
        @deltainfo_files << reference.location if (reference.type == :deltainfo)
      end

      old_repodata = File.join(@mirroring_base_dir, @local_path, '.old_repodata')
      repodata = File.join(@mirroring_base_dir, @local_path, 'repodata')
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
      parser = RMT::Rpm::Parser::DeltainfoXml.new(
        File.join(@mirroring_base_dir, @local_path, filename),
        @mirror_src
      )
      parser.parse
      @downloader.download_multi(parser.referenced_files)
    end

    @primary_files.each do |filename|
      parser = RMT::Rpm::Parser::PrimaryXml.new(
        File.join(@mirroring_base_dir, @local_path, filename),
        @mirror_src
      )
      parser.parse
      @downloader.download_multi(parser.referenced_files)
    end
  end

end
