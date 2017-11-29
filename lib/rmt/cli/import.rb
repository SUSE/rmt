class RMT::CLI::Import < RMT::CLI::Base

  desc 'data PATH', 'Read SCC data from given path'
  def data(path)
    RMT::SCC.new(options).import(path)
  end

  desc 'repos PATH', 'Mirror repos from given path'
  def repos(path)
    RMT::CLI::Mirror.new.mirror(from_dir: path)
  end

end
