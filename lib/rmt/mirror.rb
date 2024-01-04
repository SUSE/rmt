class RMT::Mirror
  RPM_FILE_NEEDLE = 'repodata/repomd.xml'.freeze
  DEB_FILE_NEEDLE = 'Release'.freeze

  attr_reader :logger, :base_dir, :mirror_sources, :is_airgapped, :repository

  def initialize(repository:, base_dir:, logger:, mirror_sources: false, is_airgapped: false)
    @repository = repository
    @logger = logger
    @base_dir = base_dir
    @mirror_sources = mirror_sources
    @is_airgapped = is_airgapped
  end

  def detect_repository_type
    search = {
      repomd: File.join(repository.external_url, RPM_FILE_NEEDLE),
      debian: File.join(repository.external_url, DEB_FILE_NEEDLE)
    }

    search.each do |key, url|
      # Current CDN authenticates via a key append to the request path
      # e.g.
      # https://update.suse.com/SUSE/product/some-product
      # becomes
      # https://update.suse.com/SUSE/product/some-product?authenication_tokensiduhashasdyashdaysdasud
      uri = URI.join(url)
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
