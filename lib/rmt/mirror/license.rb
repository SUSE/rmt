class RMT::Mirror::License < RMT::Mirror::Base
  DIRECTORY_YAST = 'directory.yast'.freeze
  def repository_url(*args)
    URI.join(repository.external_url.chomp('/') + '.license/', *args).to_s
  end

  def repository_path(*args)
    File.join(mirroring_base_dir, repository.local_path.chomp('/') + '.license/', *args)
  end

  def licenses_available?
    uri = URI.join(repository_url(DIRECTORY_YAST))
    uri.query = repository.auth_token if repository.auth_token

    request = RMT::HttpRequest.new(uri, method: :head, followlocation: true)
    request.on_success do
      return true
    end
    request.run

    logger.debug("No license directory found for repository '#{uri}'")
    false
  end

  def mirror_implementation
    return unless licenses_available?

    create_temp_dir(:license)
    directory_yast = download_cached!(DIRECTORY_YAST, to: temp(:license))

    File.readlines(directory_yast.local_path)
        .map(&:strip).reject { |item| item == 'directory.yast' }
        .map { |relative_path| file_reference(relative_path, to: temp(:license)) }
        .each { |ref| enqueue(ref) }

    download_enqueued

    replace_directory(source: temp(:license), destination: repository_path)
  rescue RMT::Downloader::Exception => e
    raise RMT::Mirror::Exception.new(_('Error while mirroring license files: %{error}') % { error: e.message })
  end



end
