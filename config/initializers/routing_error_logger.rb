module ActionDispatch
  class DebugExceptions
    alias old_log_error log_error

    def log_error(request, wrapper)
      if wrapper.exception.is_a? ActionController::RoutingError
        logger(request).send(:warn, "[404] ActionController::RoutingError (#{wrapper.exception.message})")
      else
        old_log_error request, wrapper
      end
    end
  end
end
