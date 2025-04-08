class RMT::Mirror::SumaProductTree
  FILE_URL = 'https://scc.suse.com/suma/'.freeze

  def initialize(logger:, mirroring_base_dir:, url: nil)
    @mirroring_base_dir = mirroring_base_dir
    @url = url || default_suma_url
    @logger = logger
  end

  def mirror
    # NOTE: Incase we detect the default mirror path which ends with `public/repo`,
    # we remove the `repo` sub-path since we expect the file to be stored in `public/`
    # FIXME: refactor this into cli/mirror.rb
    base_dir = mirroring_base_dir
    base_dir = File.expand_path(File.join(mirroring_base_dir, '/../')) if mirroring_base_dir == RMT::DEFAULT_MIRROR_DIR

    dest = File.join(base_dir, '/suma/')
    ref = RMT::Mirror::FileReference.new(
      relative_path: 'product_tree.json',
      base_url: url,
      base_dir: dest
    )

    logger.info _('Mirroring SUSE Manager product tree to %{dir}') % { dir: dest }
    downloader.download_multi([ref])
  rescue RMT::Downloader::Exception => e
    raise RMT::Mirror::Exception.new(_('Could not mirror SUSE Manager product tree with error: %{error}') % { error: e.message })
  end

  private

  attr_reader :mirroring_base_dir, :url, :logger

  def default_suma_url
    scc_host = Settings.try(:scc).try(:host)

    return FILE_URL if scc_host.blank?

    URI.parse(scc_host).tap { |uri| uri.path = '/suma/' }.to_s
  end

  def downloader
    @downloader ||= RMT::Downloader.new(logger: logger, track_files: false)
  end
end
