class RMT::Mirror::Base
  include RMT::Deduplicator
  include RMT::FileValidator

  attr_reader :logger, :repository

  def initialize(repository:, logger:, mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR, mirror_sources: false, is_airgapped: false)
    @repository = repository
    @mirroring_base_dir = mirroring_base_dir
    @logger = logger
    @mirror_sources = mirror_sources
    @is_airgapped = is_airgapped
    @deep_verify = false

    # don't save files for deduplication when in offline mode
    @downloader = RMT::Downloader.new(logger: logger, track_files: !is_airgapped)
    @downloader.auth_token = @repository.auth_token if @repository.auth_token.present?

    @temp_dirs = {}
    @enqueued = []
  end

  def mirror
    logger.info _('Mirroring repository %{repo} to %{dir}') % { repo: repository.name || repository_url, dir: repository_path }
    mirror_implementation
  rescue RMT::Mirror::Exception, RMT::Downloader::Exception => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring repository: %{error}' % { error: e.message }))
  ensure
    cleanup_temp_dirs
  end

  protected

  attr_accessor :temp_dirs, :downloader, :deep_verify, :is_airgapped, :mirroring_base_dir
  attr_reader :enqueued

  def file_reference(relative, to:)
    RMT::Mirror::FileReference.new(
      relative_path: relative,
      base_dir: to,
      base_url: repository_url,
      # FIXME: Check if this is fine if base_dir and cache_dir is the same!
      cache_dir: repository_path
    )
  end

  def download_cached!(relative, to:)
    ref = file_reference(relative, to: to)
    downloader.download_multi([ref])
    ref
  end

  def mirror_implementation
    raise 'Not implemented!'
  end

  def check_signature(key_file:, signature_file:, metadata_file:)
    downloader.download_multi([signature_file, key_file])

    gpg_checker = RMT::GPG.new(
      metadata_file: metadata_file.local_path,
      key_file: key_file.local_path,
      signature_file: signature_file.local_path,
      logger: logger
    )
    gpg_checker.verify_signature
  rescue RMT::Downloader::Exception => e
    if (e.http_code == 404)
      logger.info(_('Repository metadata signatures are missing'))
    else
      raise(_('Downloading repo signature/key failed with: %{message}, HTTP code %{http_code}') % { message: e.message, http_code: e.http_code })
    end
  end

  def repository_url(*args)
    URI.join(repository.external_url, *args).to_s
  end

  def repository_path(*args)
    File.join(mirroring_base_dir, repository.local_path, *args)
  end

  def create_repository_path
    FileUtils.mkpath(repository_path) unless Dir.exist?(repository_path)
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(
      _('Could not create local directory %{dir} with error: %{error}') % { dir: repository_path, error: e.message }
    )
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

  def enqueue(refs)
    @enqueued.concat(Array(refs))
  end

  def download_enqueued(continue_on_error: false)
    result = downloader.download_multi(@enqueued, ignore_errors: continue_on_error)
    @enqueued = []
    result
  end

  def need_to_download?(ref)
    return false if ref.arch == 'src' && !@mirror_sources
    return false if validate_local_file(ref)
    return false if deduplicate(ref)

    true
  end

  def replace_directory(source:, destination:, with_backup: true, &block)
    # Repomd repositories are stored within /repodata so we can use a backup for it
    # However, for Debian, repositories are stored in the top-level repository path -> backup: false

    if with_backup
      backup = File.join(File.dirname(destination), '.backup_' + File.basename(destination))
      FileUtils.remove_entry(backup) if Dir.exist?(backup)
      FileUtils.mv(destination, backup) if Dir.exist?(destination)
    end

    if block
      yield(source, destination, with_backup ? backup : nil)
    else
      FileUtils.mv(source, destination, force: true)
      FileUtils.chmod(0o755, destination)
    end
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while moving directory %{src} to %{dest}: %{error}') % {
      src: source,
      dest: destination,
      error: e.message
    })
  end

  def copy_directory_content(source:, destination:)
    replace_directory(source: source, destination: destination, with_backup: false) do
      FileUtils.mv(Dir.glob(source), destination, force: true)
    end
  end
end
