class RMT::Mirror::Base
  attr_reader :logger, :repository

  def initialize(repository:, logger:, mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR, mirror_src: false, is_airgapped: false)
    @repository = repository
    @mirroring_base_dir = mirroring_base_dir
    @logger = logger
    @mirror_src = mirror_src
    @is_airgapped = is_airgapped
    @deep_verify = false

    # don't save files for deduplication when in offline mode
    @downloader = RMT::Downloader.new(logger: logger, track_files: !is_airgapped)
    @temp_dirs = {}
  end

  def mirror
    mirror_implementation
  rescue RMT::Mirror::Exception => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring repository: %{error}' % { error: e.message }))
  ensure
    cleanup_temp_dirs
  end

  protected

  attr_accessor :temp_dirs, :downloader, :deep_verify, :is_airgapped, :mirroring_base_dir

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

  def mirror_implementation
    raise 'Not implemented!'
  end

  def repository_url(*args)
    URI.join(repository.external_url, *args).to_s
  end

  def repository_path(*args)
    File.join(mirroring_base_dir, repository.local_path, *args)
  end

  def create_temp_dir(name)
    temp_dirs[name] = Dir.mktmpdir(name.to_s)
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Could not create a temporary directory: %{error}') % { error: e.message })
  end

  def temp(name)
    unless temp_dirs.key? name
      message = _('Try to access non existing temporary directory %{name}' % { name: name })
      raise RMT::Mirror::Exception.new(message)
    end

    temp_dirs[name]
  end

  def cleanup_temp_dirs
    @temp_dirs.values.each do |temp_dir|
      FileUtils.remove_entry(temp_dir, force: true)
    end
    @temp_dirs = {}
  end
end
