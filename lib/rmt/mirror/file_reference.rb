class RMT::Mirror::FileReference
  class << self
    def build_from_metadata(metadata, base_dir:, base_url:, cache_dir: nil)
      new(base_dir: base_dir, base_url: base_url, cache_dir: cache_dir, location: metadata.location)
        .tap do |file|
          file.arch = metadata.arch
          file.checksum = metadata.checksum
          file.checksum_type = metadata.checksum_type
          file.size = metadata.size
          file.type = metadata.type
        end
    end
  end

  attr_reader :cache_path, :local_path, :remote_path, :location
  attr_accessor :arch, :checksum, :checksum_type, :size, :type

  def initialize(base_dir:, base_url:, cache_dir: nil, location:)
    @cache_path = (cache_dir ? File.join(cache_dir, location) : nil)
    @local_path = File.join(base_dir, location.gsub(/\.\./, '__'))
    @remote_path = URI.join(base_url, location)
    @location = location
  end

  def cache_timestamp
    File.mtime(cache_path).utc.httpdate if cache_path && File.exist?(cache_path)
  end
end
