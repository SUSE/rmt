require 'byebug'
require 'xz'

class RMT::Mirror::Debian < RMT::Mirror::Base
  include RMT::FileValidator

  attr_reader :release

  def initialize(logger:, base_dir:, repo:, mirror_sources: false, airgapped: false)
    base_config = {
      logger: logger,
      base_dir: base_dir,
      repo: repo,
      mirror_sources: mirror_sources,
      airgapped: airgapped
    }
    super(**base_config)

    uri = URI(repo.external_url)
    base_uri, _ = repo.external_url.split(/dists/,2)
    base_path, release = uri.path.split(/dists/,2)
    matched = release.match(/\/(.+)\//)

    @release = matched[1]
    @repo_dir = File.join(base_dir, base_path)
    @repo_url = URI.join(base_uri, base_path)
  end

  def mirror_with_implementation!
    # FIXME: This should all go into `public/debian/*` directory!
    create_dir repository_path
    create_temp :dists

    metadata = mirror_metadata

    mirror_packages(metadata)

    move_dir(source: File.join(temp(:dists), 'dists'), dest: repository_path('dists'))
  end

  def dists_path(*subdirectories)
    File.join('dists', release, *subdirectories)
  end

  def dists_url(*subdirectories)
    # Ensure we end on '/' to make URI later on happy
    File.join(repo_url.to_s, dists_path(*subdirectories), '/')
  end

  def parse_release_file(ref)
    metadata = []
    # We are only interested in sha256 sums
    checksum_found = false
    File.foreach(ref.local_path, chomp: true) do |line|
      if line == 'SHA256:'
        checksum_found = true
        next
      end
      next unless checksum_found
      matched = line.match(/^\s([a-z0-9]{64})\s+(\d+)\s+(.+)$/)

      # FIXME: Do not iterate over all the crap after the sha256 sums
      next unless matched

      ref = RMT::Mirror::FileReference.new(
        relative_path: matched[3],
        # FIXME: This is looking like I messed up in base it should got to temp not to temp/dists/:release
        base_dir: File.join(temp(:dists), 'dists', release),
        base_url: dists_url,
        cache_dir: dists_path
      )
      ref.tap do |r|
        r.checksum = matched[1]
        r.checksum_type = 'SHA256'
        r.size = matched[2].to_i
      end

      # Release does include the uncompressed filename while in realtiy this files
      # are normally not existing on the remote host...
      # Nice specs here!
      metadata << ref if ['.gz', '.xz'].include? ref.remote_path.to_s.last(3)
    end
    metadata
  end

  def mirror_metadata
    release_file = download_cached!(dists_path('Release'), to: temp(:dists))
    metadata = parse_release_file(release_file)

    metadata.each { |ref| enqueue ref }

    # FIXME: Add sha256 checking
    # FIXME: Add by-hash support!

    download_enqueued
    metadata
  end

  def parse_packages_file(source)
    paths = {
      base_dir: repo_dir,
      base_url: repo_url,
      cache_dir: nil
    }

    packages = []

    XZ::StreamReader.open(source.local_path) do |fd|
      attributes = {}

      loop do
        l = fd.readline.chomp

        if l.empty?
          break if fd.eof?

          ref = RMT::Mirror::FileReference.new(relative_path: attributes[:filename], **paths)
          ref.tap do |r|
            r.arch = attributes[:architecture]
            r.checksum_type = 'SHA256'
            r.checksum = attributes[:sha256]
            r.size = attributes[:size].to_i
          end

          packages << ref
          attributes = {}
          next
        end

        name, value = l.split(/: /, 2)
        attributes[name.downcase.to_sym] = value
      end
    end
    packages
  end

  def mirror_packages(metadata)
    # FIXME: Allow multiple compressions here but decide for one file only
    sources = metadata.select do |ref|
      # FIXME: Allow Sources to be mirrored as well
      ref.compression == :xz && ref.remote_path.to_s.end_with?('Packages.xz')
    end

    sources.each do |ref|
      logger.debug("Reading package list from #{ref.local_path}..")
      packages = parse_packages_file(ref)

      packages.each do |ref|
        logger.debug("~ #{File.basename(ref.local_path)} is up to date")
        next if validate_local_file(ref)

        enqueue ref
      end

      download_enqueued
    end
  end
end
