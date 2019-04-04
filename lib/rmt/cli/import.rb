class RMT::CLI::Import < RMT::CLI::Base

  desc 'data PATH', _('Read SCC data from given path')
  def data(path)
    RMT::Lockfile.lock do
      needs_path(path)
      RMT::SCC.new(options).import(path)
    end
  end

  desc 'repos PATH', _('Mirror repos from given path')
  def repos(path)
    RMT::Lockfile.lock do
      needs_path(path)

      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger, airgap_mode: true)

      repos_file = File.join(path, 'repos.json')
      raise RMT::CLI::Error.new(_('%{file} does not exist.') % { file: repos_file }) unless File.exist?(repos_file)

      begin
        mirror.mirror_suma_product_tree(repository_url: 'file://' + path + '/suma/')
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
          mirror.mirror(
            repository_url: 'file://' + path + Repository.make_local_path(repo_json['url']),
            local_path: Repository.make_local_path(repo.external_url),
            auth_token: repo.auth_token,
            repo_name: repo.name
          )

          repo.refresh_timestamp!
        rescue RMT::Mirror::Exception => e
          logger.warn e.to_s
        end
      end
    end
  end

end
