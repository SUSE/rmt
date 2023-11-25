class RMT::Mirror::Base
  attr_reader :logger, :repo_dir, :repo_url, :repo, :mirror_sources, :airgap_mode

  def initialize(logger:, base_dir:, repo:, mirror_sources: false, airgapped: false)
    @logger = logger
    @repo_dir = File.join(base_dir, repo.local_path)
    @repo_url = repo.external_url
    @repo = repo
    @mirror_sources = mirror_sources
    @airgap_mode = airgapped

    @temp_directories = {}
    @enqueued = []
  end

  def mirror_repository!
    mirror_with_implementation!
  rescue RMT::Mirror::Exception => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring repository: %{error}' % { error: e.message }))
  ensure
    cleanup_temp_directories
  end

  protected

  attr_reader :temp_directories, :enqueued

  def mirror_with_implementation!
    raise 'Implement me!'
  end

  # API
  def create_temp(*temps)
    temps.each do |name|
      temp_directories[name] = Dir.mktmpdir(name.to_s)
    end
  rescue StandardError => e
    message = _('Could not create a temporary directory: %{error}' % { error: e.message })
    raise RMT::Mirror::Exception.new(message)
  end

  def temp(name)
    raise RMT::Mirror::Exception.new(_('Try to access non existing temporary directory %{name}' % { name: name })) unless temp_directories.key? name

    temp_directories[name]
  end

  def optional(action)
    yield
  rescue StandardError => e
    message = _('Skipped %{action}: %{error}' % { action: action, error: e.message })
    logger.debug(message)
  end

  def download_cached!(relative, to:)
    # In this instance we download the file if it is not available
    # in the the current mirrored repository data or copy it from
    # the existing repository data. This is why base_dir and cache_dir
    # is switched!
    ref = RMT::Mirror::FileReference.new(
      relative_path: relative,
      base_dir: to,
      base_url: repository_url,
      cache_dir: repository_path
)

    downloader.download_multi([ref])
    ref
  end

  def enqueue(ref)
    @enqueued << ref
  end

  def download_enqueued(continue_on_error: false)
    result = downloader.download_multi(@enqueued, ignore_errors: continue_on_error)
    @enqueued = []
    result
  end

  def repository_path(*subdirectories)
    File.join(repo_dir, *subdirectories)
  end

  def repository_url(*subdirectories)
    URI.join(repo_url, *subdirectories).to_s
  end

  def create_dir(directory)
    FileUtils.mkpath(directory) unless Dir.exist?(directory)
  rescue StandardError => e
    message = _('Could not create local directory %{dir} with error: %{error}') % { dir: directory, error: e.message }
    raise RMT::Mirror::Exception.new(message)
  end

  def move_dir(source:, dest:)
    old = File.join(File.dirname(dest), '.old_' + File.basename(dest))

    FileUtils.remove_entry(old) if Dir.exist?(old)
    FileUtils.mv(dest, old) if Dir.exist?(dest)
    FileUtils.mv(source, dest, force: true)
    FileUtils.chmod(0o755, dest)
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while moving directory %{src} to %{dest}: %{error}') % {
      src: source,
      dest: dest,
      error: e.message
    })
  end

  private

  def downloader
    @downloader ||= RMT::Downloader.new(logger: logger, track_files: !airgap_mode)
  end

  def cleanup_temp_directories
    temp_directories.values.each { |d| FileUtils.remove_entry(d, force: true) }
  end
end
