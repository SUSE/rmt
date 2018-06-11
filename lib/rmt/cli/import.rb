class RMT::CLI::Import < RMT::CLI::Base

  desc 'data PATH', 'Read SCC data from given path'
  def data(path)
    RMT::Lockfile.lock do
      needs_path(path) do
        RMT::SCC.new(options).import(path)
      end
    end
  end

  desc 'repos PATH', 'Mirror repos from given path'
  def repos(path)
    RMT::Lockfile.lock do
      needs_path(path) do
        logger = RMT::Logger.new(STDOUT)
        mirror = RMT::Mirror.new(logger: logger, disable_hardlinks: true)

        repos_file = File.join(path, 'repos.json')
        unless File.exist?(repos_file)
          warn "#{repos_file} does not exist."
          return # FIXME: needs to raise exception
        end

        repos = JSON.parse(File.read(repos_file))
        repos.each do |repo_json|
          repo = Repository.find_by(external_url: repo_json['url'])
          if repo.nil?
            warn "repository by url #{repo_json['url']} does not exist in database"
            next
          end

          repo.external_url = 'file://' + path + Repository.make_local_path(repo_json['url'])
          # mirror!(repo, repository_url: repo_json['url'], to_offline: true, logger: logger)

          begin
            local_path = Repository.make_local_path(repo_json['url'])
            logger.info "Mirroring repository #{repo.name} to #{local_path}"

            mirror.mirror(
              repository_url: repo.external_url,
              local_path: local_path,
              auth_token: repo.auth_token
            )

            repo.refresh_timestamp!
          rescue RMT::Mirror::Exception => e
            logger.warn e.to_s
          end
        end
      end
    end
  end

end
