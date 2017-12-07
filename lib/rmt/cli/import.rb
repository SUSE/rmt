class RMT::CLI::Import < RMT::CLI::Base

  desc 'data PATH', 'Read SCC data from given path'
  def data(path)
    needs_path(path) do
      RMT::SCC.new(options).import(path)
    end
  end

  desc 'repos PATH', 'Mirror repos from given path'
  def repos(path)
    needs_path(path) do
      repos = Repository.where(mirroring_enabled: true)
      if repos.empty?
        warn 'There are no repositories marked for mirroring.'
        return
      end

      repos.each do |repo|
        require 'byebug'; byebug
        repo.external_url.sub!(/.*(?=SUSE)/, "file://#{path}/") # FIXME: this won't work for some repos
        mirror(repo)
      end
    end
  end

end
