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
      repos = Repository.find(repos_ids)

      if repos.empty?
        warn 'There are no repositories marked for mirroring.'
        return
      end

      base_dir = path

      repos.each do |repository|
        begin
          puts "Mirroring repository #{repository.name} to #{base_dir}"
          RMT::Mirror.from_repo_model(repository, base_dir).mirror
          repository.refresh_timestamp!
        rescue RMT::Mirror::Exception => e
          warn e.to_s
        end
      end
    end
  end

  private

  def needs_path(path)
    File.directory?(path) ? yield : warn("#{path} is not a directory.")
  end
end
