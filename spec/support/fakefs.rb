class FakeFS::File
  def flock(_mode)
    42 # this is a stub. see https://www.rubydoc.info/github/defunkt/fakefs/FakeFS/File
  end
end

# this makes lockfile dir to be present in cleaned FakeFS setup
module FakeFS
  class << self
    def with_fresh(&block)
      clear!
      FileUtils.mkdir_p(File.dirname(RMT::Lockfile::LOCKFILE_LOCATION))
      with(&block)
    end
  end
end
