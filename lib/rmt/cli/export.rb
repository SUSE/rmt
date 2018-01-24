class RMT::CLI::Export < RMT::CLI::Base

  desc 'scc-data PATH', 'Store SCC data in files at given path'
  def scc_data(path)
    needs_path(path) do
      RMT::SCC.new(options).export(path)
    end
  end

  desc 'settings PATH', 'Store repository settings at given path'
  def settings(path)
    needs_path(path) do
      data = Repository.only_mirrored.inject([]) { |data, repo| data << { url: repo.external_url, auth_token: repo.auth_token.to_s } }
      File.write(File.join(path, 'repos.json'), data.to_json)
      puts "Settings saved at #{path}."
    end
  end

  desc 'repos PATH', 'Mirror repos at given path'
  long_desc <<-REPOS
  Run this command on an online RMT.
  It will look in PATH for a repos.json file which has to contain a list of repository IDs.
  Usually, this file gets created by an offline RMT with `export settings`.

  `export repos` will mirror these repositories to this PATH, usually a portable storage device.
  REPOS
  def repos(path)
    needs_path(path) do
      repos_file = File.join(path, 'repos.json')
      unless File.exist?(repos_file)
        warn "#{repos_file} does not exist."
        return
      end
      repos = JSON.parse(File.read(repos_file))
      repos.each do |repo|
        puts "Mirroring repository at #{repo['url']}"
        begin
          RMT::Mirror.from_url(repo['url'], repo['auth_token'], base_dir: path).mirror
        rescue RMT::Mirror::Exception => e
          warn e.to_s
        end
      end
    end
  end

end
