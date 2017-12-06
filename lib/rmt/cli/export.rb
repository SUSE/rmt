# rubocop:disable Rails/Output

class RMT::CLI::Export < RMT::CLI::Base

  desc 'settings PATH', 'Store repository settings at given path'
  def settings(path)
    needs_path(path) do
      File.write(File.join(path, 'repos.json'), Repository.only_mirrored.pluck(:id).to_json)
      puts "Settings saved at #{path}."
    end
  end

  desc 'data PATH', 'Store SCC data in files at given path'
  def data(path)
    needs_path(path) do
      RMT::SCC.new(options).export(path)
    end
  end

  desc 'repos PATH', 'Mirror repos at given path'
  # TODO: needs a long_desc to explain the connection with the repos.json
  def repos(path)
    needs_path(path) do
      repos_file = File.join(path, 'repos.json')
      repos_ids = JSON.parse(File.read(repos_file))

      repos_ids.each do |id|
        repository = Repository.find_by_id(id)
        if repository
          begin
            puts "Mirroring repository #{repository.name} to #{path}"
            RMT::Mirror.from_repo_model(repository, path).mirror
            repository.refresh_timestamp!
          rescue RMT::Mirror::Exception => e
            warn e.to_s
          end
        else
          warn "No repo with id #{id} found in database."
        end
      end
    end
  end

  private

  def needs_path(path)
    File.directory?(path) ? yield : warn("#{path} is not a directory.")
  end
end
