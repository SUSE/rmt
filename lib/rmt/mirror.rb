class RMT::Mirror
  RPM_FILE_NEEDLE = 'repodata/repomd.xml'.freeze
  DEB_FILE_NEEDLE = 'Release'.freeze

  attr_reader :logger, :mirroring_base_dir, :mirror_sources, :is_airgapped, :repository

  def initialize(repository:, mirroring_base_dir:, logger:, mirror_sources: false, is_airgapped: false)
    @repository = repository
    @logger = logger
    @mirroring_base_dir = mirroring_base_dir
    @mirror_sources = mirror_sources
    @is_airgapped = is_airgapped
  end

  def mirror_now
    configuration = { repository: repository,
                      logger: logger,
                      mirroring_base_dir: mirroring_base_dir,
                      mirror_sources: mirror_sources,
                      is_airgapped: is_airgapped }

    instance = repository_mirror_class.new(**configuration)
    instance.mirror
  end

  protected

  def repository_mirror_class
    case repository_type
    when :repomd
      RMT::Mirror::Repomd
    when :debian
      RMT::Mirror::Debian
    else
      raise(RMT::Mirror::Exception.new('Unknown repository type'))
    end
  end

  def repository_type
    # We search repomd structure first since it is more common
    # Debian is less common

    search = {
      repomd: File.join(repository.external_url, RPM_FILE_NEEDLE),
      debian: File.join(repository.external_url, DEB_FILE_NEEDLE)
    }

    search.each do |key, url|
      uri = URI.join(url)

      # If we dealing with a file:/// scheme we do not actually
      # make a head request but check if the file exists locally
      if uri.scheme == 'file'
        return key if File.exist?(uri.path)

        next
      end

      # Current CDN authenticates via a key append to the request path
      # e.g.
      # https://update.suse.com/SUSE/product/some-product
      # becomes
      # https://update.suse.com/SUSE/product/some-product?authenication_tokensiduhashasdyashdaysdasud
      uri.query = @repository.auth_token if @repository.auth_token

      request = RMT::HttpRequest.new(uri, method: :head, followlocation: true)
      request.on_success do
        return key
      end
      request.run
    end
    nil
  end
end
