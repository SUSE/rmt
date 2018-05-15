class RMT::Lockfile
  LOCKFILE_LOCATION = '/run/lock/rmt/.lock'.freeze
  ExecutionLockedError = Class.new(StandardError)

  class << self
    def lock
      File.open(RMT::Lockfile::LOCKFILE_LOCATION, File::RDWR | File::CREAT) do |f|
        raise ExecutionLockedError unless f.flock(File::LOCK_EX | File::LOCK_NB)
        f.write(Process.pid.to_s)

        yield
      end
    end
  end
end
