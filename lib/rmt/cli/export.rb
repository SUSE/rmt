class RMT::CLI::Export < RMT::CLI::Base

  desc 'data PATH', 'Store SCC data in files at given path'
  def data(path)
    needs_path(path, writable: true)
    RMT::SCC.new(options).export(path)
  end

  desc 'settings PATH', 'Store repository settings at given path'
  def settings(path)
    needs_path(path, writable: true)
    filename = File.join(path, 'repos.json')

    data = Repository.only_mirrored.inject([]) { |data, repo| data << { url: repo.external_url, auth_token: repo.auth_token.to_s } }
    File.write(filename, data.to_json)
    puts "Settings saved at #{filename}."
  end

  desc 'repos PATH', 'Mirror repos at given path'
  long_desc <<-REPOS
  Run this command on an online RMT.
  It will look in PATH for a repos.json file which has to contain a list of repository IDs.
  Usually, this file gets created by an offline RMT with `export settings`.

  `export repos` will mirror these repositories to this PATH, usually a portable storage device.
  REPOS
  def repos(path)
    needs_path(path, writable: true)

    logger = RMT::Logger.new(STDOUT)
    mirror = RMT::Mirror.new(mirroring_base_dir: path, logger: logger, airgap_mode: true)

    repos_file = File.join(path, 'repos.json')
    raise RMT::CLI::Error.new("#{repos_file} does not exist.") unless File.exist?(repos_file)

    repos = JSON.parse(File.read(repos_file))
    repos.each do |repo|
      begin
        mirror.mirror(
          repository_url: repo['url'],
          local_path: Repository.make_local_path(repo['url']),
          auth_token: repo['auth_token']
        )
      rescue RMT::Mirror::Exception => e
        warn e.to_s
      end
    end
  end

end
