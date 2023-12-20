class RMT::Mirror::Debian < RMT::Mirror::Base
  RELEASE_FILE_NAME = 'Release'.freeze
  def mirror_implementation
    create_temp_dir(:metadata)
    release = download_cached!(repository_url(RELEASE_FILE_NAME), to: temp(:metadata))

  end

  def repository_url(*args)
    File.join(repository.external_url, *args)
  end

  def repository_path
  end

end
