module Registry::Exceptions
  class InvalidScope < StandardError
    attr_accessor :status

    def initialize(message = nil, status = 400)
      @status = status
      super(message)
    end
  end

  class InvalidCredentials < StandardError
    attr_accessor :status

    def initialize(message: nil, status: 401, login: nil)
      Rails.logger.warn "Invalid credentials provided for login '#{login}'"
      @status = status
      super(message)
    end
  end

  # the registry cannot serve the request for a reason on this host: a signing
  # key or policy file that was never installed, or the registry itself not
  # answering
  # Kept apart from the errors above because the cause is entirely server-side,
  # even though it does not return 5XX,
  # so the distinction lives in the log rather than in the status
  class RegistryUnavailable < StandardError
    attr_accessor :status

    def initialize(message = nil, status = 401)
      @status = status
      super(message)
    end
  end
end
