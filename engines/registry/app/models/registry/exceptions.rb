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
end
