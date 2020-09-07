class RMT::Lockfile
  ExecutionLockedError = Class.new(StandardError)

  class << self
    def lock(lock_name = nil)
      lock_name = ['rmt-cli', lock_name].compact.join('-')

      is_lock_obtained = obtain_lock(lock_name)
      unless is_lock_obtained
        raise ExecutionLockedError.new(
          _('Another instance of this command is already running. Terminate the other instance or wait for it to finish.')
        )
      end

      yield

      release_lock(lock_name)
    end

    protected

    def obtain_lock(lock_name)
      quoted_lock_name = ActiveRecord::Base.connection.quote(lock_name)
      # get_lock returns 1 if lock was obtained, 0 otherwise
      result = ActiveRecord::Base.connection.execute("SELECT GET_LOCK(#{quoted_lock_name}, 1)")
      result.first.first == 1
    end

    def release_lock(lock_name)
      quoted_lock_name = ActiveRecord::Base.connection.quote(lock_name)
      ActiveRecord::Base.connection.execute("SELECT RELEASE_LOCK(#{quoted_lock_name})")
    end
  end
end
