class RMT::Mirror::FileReference
  class << self
    def build_from_metadata(metadata, base_dir:, base_url:, cache_dir: nil)
      new(
        relative_path: metadata.location,
        base_dir: base_dir,
        base_url: base_url,
        cache_dir: cache_dir
      ).tap do |file|
        file.arch = metadata.arch
        file.checksum = metadata.checksum
        file.checksum_type = metadata.checksum_type
        file.size = metadata.size
        file.type = metadata.type
      end
    end
  end

  attr_accessor :arch, :checksum, :checksum_type, :size, :type
  attr_accessor :base_dir, :base_url, :cache_dir, :relative_path

  def initialize(relative_path:, base_dir:, base_url:, cache_dir: nil)
    @base_dir = base_dir
    @base_url = base_url
    @cache_dir = cache_dir
    @relative_path = relative_path
  end

  def cache_path
    @cache_dir ? File.join(@cache_dir, @relative_path) : nil
  end

  def local_path
    File.join(@base_dir, @relative_path.gsub(/\.\./, '__'))
  end

  def sanitise_relative_path
    encoded_filename = File.basename(@relative_path)
    # INFO: Encode the filename of the URI to make RMT handle
    # RFC3986-incompliant filenames (e.g. containing special characters)
    encoded_filename = ERB::Util.url_encode(encoded_filename)
    File.join(File.dirname(@relative_path), encoded_filename)
  end

  def remote_path
    URI.join(@base_url, sanitise_relative_path)
  end

  def cache_timestamp
    File.mtime(cache_path).utc if cache_path && File.exist?(cache_path)
  end
end
