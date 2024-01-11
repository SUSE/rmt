class RMT::CLI::Import < RMT::CLI::Base

  desc 'data PATH', _('Read SCC data from given path')
  def data(path)
    RMT::Lockfile.lock do
      path = needs_path(path)
      RMT::SCC.new(options).import(path)
    end
  end

  desc 'repos PATH', _('Mirror repos from given path')
  def repos(path)
    RMT::Lockfile.lock do
      path = needs_path(path)
      repos_file = File.join(path, 'repos.json')

      raise RMT::CLI::Error.new(_('%{file} does not exist.') % { file: repos_file }) unless File.exist?(repos_file)

      begin
        exported_suma_path = File.join(path, '/suma/')
        suma_repo_url = URI.join('file://', exported_suma_path).to_s
        suma_product_tree = RMT::Mirror::SumaProductTree.new(mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR, logger: logger, url: suma_repo_url)
        suma_product_tree.mirror
      rescue RMT::Mirror::Exception => e
        logger.warn(e.message)
      end

      repos = JSON.parse(File.read(repos_file))
      repos.each do |repo_json|
        repo = Repository.find_by(external_url: repo_json['url'])

        if repo.nil?
          warn _('repository by URL %{url} does not exist in database') % { url: repo_json['url'] }
          next
        end

        begin
          exported_repo_path = File.join(path, Repository.make_local_path(repo_json['url']))
          repo_url = URI.join('file://', exported_repo_path).to_s
          repo.external_url = repo_url

          configuration = {
            repository: repo,
            logger: logger,
            mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR,
            mirror_sources: RMT::Config.mirror_src_files?,
            is_airgapped: true
          }
          RMT::Mirror.new(**configuration).mirror_now

          repo.refresh_timestamp!
        rescue RMT::Mirror::Exception => e
          logger.warn e.to_s
        end
      end
    end
  end

end
