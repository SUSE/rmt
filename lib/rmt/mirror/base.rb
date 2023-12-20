class RMT::Mirror::Base
  attr_reader :downloader, :logger, :deep_verify, :repository

  def initialize(repository:, logger:, mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR, mirror_src: false, is_airgapped: false)
    @repository = repository
    @mirroring_base_dir = mirroring_base_dir
    @logger = logger
    @mirror_src = mirror_src
    @is_airgapped = is_airgapped
    @deep_verify = false
    @tmp_dirs = {}

    # don't save files for deduplication when in offline mode
    @downloader = RMT::Downloader.new(logger: logger, track_files: !is_airgapped)
  end

  def download_cached!(relative, to:)
    ref = RMT::Mirror::FileReference.new(
      relative_path: relative,
      base_dir: to,
      base_url: repository_url,
      cache_dir: repository_path
    )

    downloader.download_multi([ref])
    ref
  end

  def mirror
    mirror_implementation
  rescue RMT::Mirror::Exception => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring repository: %{error}' % { error: e.message }))
  ensure
    cleanup_tmp_dirs
  end

  def mirror_implementation
    raise 'Not implemented!'
  end

  def repository_url
    raise 'Not implemented!'
  end

  def repository_path
    raise 'Not Implemented!'
  end

  def create_temp_dir(name)
    @tmp_dirs[name] = Dir.mktmpdir
  rescue StandardError => e
    raise RMT::Mirror::Repomd::Exception.new(_('Could not create a temporary directory: %{error}') % { error: e.message })
  end

  def temp(name)
    @tmp_dirs[name]
  end

  def cleanup_tmp_dirs
    @tmp_dirs.values.each do |tmp_dir|
      FileUtils.remove_entry(tmp_dir, force: true)
    end
  end
end
