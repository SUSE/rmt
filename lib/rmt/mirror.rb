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
      request = RMT::HttpRequest.new(url, method: :head, followlocation: true)
      request.on_success do
        return key
      end
      request.run
    end
    nil
  end
end
