module RMT::Synchronization
  class RMT::Synchronization::Exception < RuntimeError
  end

  class RMT::Synchronization::Base
    def initialize(offline:, online:, logger:)
      offline_path = offline
      online_url = online
      temp_dirs = {}

      @logger = logger
    end

    def mirror_repository!
      mirror_with_implementation!
    rescue StandardError => e
      raise RMT::Synchronization::Exception.new(_('Error while mirroring repository: %{error}') % { error: e.message })
    ensure
      cleanup_temp_directories
    end

    protected

    def mirror_with_implementation!
      raise 'Implement me!'
    end

    # API
    def create_temp(*temps)
      temps.each do |name|
        tem_directories[name] << Dir.mktmpdir('rmt')
      end
    rescue StandardError => e
      message = _('Could not create a temporary directory: %{error}') % { error: e.message })
      raise RMT::Synchronization::Exception.new(message)
    end

    def optional
    end

    def download_now!(path, to:)
    end

    def enqueue(pkg)
    end

    def download_enqueued
    end

    def download_enqueued!
    end

    attr_accessor :offline_path
    attr_accessor :online_url
    attr_accessor :temp_directories
    attr_reader :logger

    private

    def cleanup_temp_directories
      temp_directories.each { |d| FileUtils.remove_entry(d, force = true) }
    end
  end
end

#
##
#
# class RMT::Synchronization::Reference
#   attr_reader :offline_path, :online_url, :cache_dir
#   attr_accessor 
#
  attr_reader :cache_path, :local_path, :remote_path
#
# class RMT::Synchronization::Repomd < RMT::Synchronization::Base
#   def synchronize
#     create_temp :licenses, :metadata
#   set_auth_token auth_token
#
#     # 1. Licenses
  #   optional do
  #     without_auth do
  #       diryast = download_now!('.licenses/directory.yast', to: temp(:licences))
  #       licences = parse_yast_directory(diryast.content)
  #       licences.each { |l| enqueue(l) }
  #     end
  #   end
  #
  #   download_enqueued!
  #
  #   # 2. Metadata
  #   repomd_xml = download_now!('repodata/repomd.xml', to: temp(:metadata))
  #
  #   optional do
  #     signature = download_now!('repodata/repomd.xml.asc'. to: temp(:metadata))
  #     key       = download_now!('repodata/repomd.xml.key'. to: temp(:metadata))
  #
  #     repomd_xml.verify_signature(key: key, signature: signature)
  #   end
  #
  #   repomd = parse_repomd_xml(repomd_xml)
  #   repomd.each { |meta| enqueue(meta) }
  #
  #   download_enqueued!
  #
  #
  #   # 3. Packages
  #
  #   sources = repomd.select { |ref| ref.type.include?(:deltainfo, :primary) }
  #   sources.each do |source|
  #     packages = case source.type
  #       when :primary then RepomdParser::PrimaryXmlParser
  #       when :deltainfo then RepomdParser::DeltainfoXmlParser
  #     end.parse(source.content)
  #
  #     packages.each do |pkg|
  #       next unless pkg.source_type? && mirror_package_sources
  #       next if pkg.uptodate?
  #       next if deduplicated(pkg)
  #
  #       enqueue(pkg)
  #     end
  #   end
  #
  #   download_enqueued
  #
  #   copy_dir(
  #
  # end
#end
  #
  #   
  #
  #
    xml_parsers = { deltainfo: RepomdParser::DeltainfoXmlParser,
                    primary: RepomdParser::PrimaryXmlParser }

    metadata_references
      .map { |file| xml_parsers[file.type]&.new(file.local_path) }.compact
      .map(&:parse).flatten
  #
  #
  #
  #
  #
  #
  #
  #
  #
  #
  #
  #
    metadata_files = RepomdParser::RepomdXmlParser.new(repomd_xml.local_path).parse
      .map { |reference| FileReference.build_from_metadata(reference, **mirroring_paths) }
  #
  #
  def mirror_packages(metadata_files, repository_dir, repository_url)
    package_references = parse_packages_metadata(metadata_files)

    package_file_references = package_references.map do |reference|
      FileReference.build_from_metadata(reference,
                                        base_dir: repository_dir,
                                        base_url: repository_url)
    end

    failed_downloads = download_package_files(package_file_references)

    raise _('Failed to download %{failed_count} files') % { failed_count: failed_downloads.size } unless failed_downloads.empty?
  rescue StandardError => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring packages: %{error}') % { error: e.message })
  end

  def parse_packages_metadata(metadata_references)
    xml_parsers = { deltainfo: RepomdParser::DeltainfoXmlParser,
                    primary: RepomdParser::PrimaryXmlParser }

    metadata_references
      .map { |file| xml_parsers[file.type]&.new(file.local_path) }.compact
      .map(&:parse).flatten
  end

  def download_package_files(file_references)
    files_to_download = file_references.select { |file| need_to_download?(file) }
    return [] if files_to_download.empty?

    downloader.download_multi(files_to_download, ignore_errors: true)
  end

  def need_to_download?(file)
    return false if file.arch == 'src' && !mirror_src
    return false if validate_local_file(file)
    return false if deduplicate(file)

    true
  end
  #
  #
  #
  #
  #
      signature_file = FileReference.new(relative_path: 'repodata/repomd.xml.asc', **mirroring_paths)
      key_file       = FileReference.new(relative_path: 'repodata/repomd.xml.key', **mirroring_paths)
      # mirror repomd.xml.asc first, because there are repos with repomd.xml.asc but without repomd.xml.key
      downloader.download_multi([signature_file])
      downloader.download_multi([key_file])
  #     
  #     
  #
  #   
  #
    repomd_xml = FileReference.new(relative_path: 'repodata/repomd.xml', **mirroring_paths)
  #
  #   
  #
  #   
  #
  #   
  #
    mirroring_paths = {
      base_url: URI.join(repository_url),
      base_dir: temp_metadata_dir,
      cache_dir: repository_dir
    }

    repomd_xml = FileReference.new(relative_path: 'repodata/repomd.xml', **mirroring_paths)
    downloader.download_multi([repomd_xml])

    begin
      signature_file = FileReference.new(relative_path: 'repodata/repomd.xml.asc', **mirroring_paths)
      key_file       = FileReference.new(relative_path: 'repodata/repomd.xml.key', **mirroring_paths)
      # mirror repomd.xml.asc first, because there are repos with repomd.xml.asc but without repomd.xml.key
      downloader.download_multi([signature_file])
      downloader.download_multi([key_file])

      RMT::GPG.new(
        metadata_file: repomd_xml.local_path,
        key_file: key_file.local_path,
        signature_file: signature_file.local_path,
        logger: logger
      ).verify_signature
    rescue RMT::Downloader::Exception => e
      if (e.http_code == 404)
        logger.info(_('Repository metadata signatures are missing'))
      else
        raise(_('Downloading repo signature/key failed with: %{message}, HTTP code %{http_code}') % { message: e.message, http_code: e.http_code })
      end
    end
#
#
#
#     
#
#
#
#     # 2. 
#
#     
#
#     
#
#
#
#
#
#
#   def mirror(repository_url:, local_path:, auth_token: nil, repo_name: nil)
#     repository_dir = File.join(mirroring_base_dir, local_path)
#
#     logger.info _('Mirroring repository %{repo} to %{dir}') % { repo: repo_name || repository_url, dir: repository_dir }
#
#     create_repository_dir(repository_dir)
#
#     temp_licenses_dir = create_temp_dir
#     temp_metadata_dir = create_temp_dir
#
#     # downloading license doesn't require an auth token
#     mirror_license(repository_dir, repository_url, temp_licenses_dir)
#
#     downloader.auth_token = auth_token
#     metadata_files = mirror_metadata(repository_dir, repository_url, temp_metadata_dir)
#     mirror_packages(metadata_files, repository_dir, repository_url)
#
#     replace_directory(temp_licenses_dir, repository_dir.chomp('/') + '.license/') if Dir.exist?(temp_licenses_dir)
#     replace_directory(File.join(temp_metadata_dir, 'repodata'), File.join(repository_dir, 'repodata'))
#   ensure
#     [temp_licenses_dir, temp_metadata_dir].each { |dir| FileUtils.remove_entry(dir, true) }
#   end
#
#
#   end
#
#
# end
#
