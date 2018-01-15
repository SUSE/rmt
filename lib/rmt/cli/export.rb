class RMT::CLI::Export < RMT::CLI::Base

  desc 'data PATH', 'Store SCC data in files at given path'
  def data(path)
    needs_path(path) do
      RMT::SCC.new(options).export(path)
    end
  end

  desc 'settings PATH', 'Store repository settings at given path'
  def settings(path)
    needs_path(path) do
      File.write(File.join(path, 'repos.json'), Repository.only_mirrored_ids.to_json)
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
      repos_ids = JSON.parse(File.read(repos_file))
      repos_ids.each do |id|
        repo = Repository.find_by(id: id)
        repo ? mirror(repo, to: path) : warn("No repo with id #{id} found in database.")
      end
    end
  end

end
