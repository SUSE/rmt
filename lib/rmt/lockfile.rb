class RMT::Lockfile
  LOCKFILE_LOCATION = File.expand_path('../../tmp/rmt.lock', __dir__).freeze
  ExecutionLockedError = Class.new(StandardError)

  class << self
    def create_file
      dirname = File.dirname(LOCKFILE_LOCATION)
      FileUtils.mkdir_p(dirname) unless File.directory?(dirname)

      # has to be a class instance variable otherwise garbage-collected and lock is removed
      @f = File.open(RMT::Lockfile::LOCKFILE_LOCATION, File::RDWR | File::CREAT)
      @f.write(Process.pid.to_s) if @f.read.empty? # write PID if file is new. this has to be done before locking
      raise ExecutionLockedError unless @f.flock(File::LOCK_EX | File::LOCK_NB)
    end

    def remove_file
      File.delete(LOCKFILE_LOCATION) if File.exist?(LOCKFILE_LOCATION)
    end
  end
end
