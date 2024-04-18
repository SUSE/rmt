class Registry::AuthenticatedClient
  include RegistryClient

  attr_reader :auth_strategy

  def initialize(login, password)
    authenticate_by_system_credentials(login, password)
    if @auth_strategy
      Rails.logger.info("Authenticated '#{self}'")
    else
      raise Registry::Exceptions::InvalidCredentials.new(login: login)
    end
  end

  private

  def authenticate_by_system_credentials(login, password)
    @systems = System.get_by_credentials(login, password)
    if @systems.any? { |system| system.last_seen_at > Settings[:registry].token_expiration.seconds.ago }
      @account = login
      @auth_strategy = :system_credentials
    end
    @auth_strategy
  end
end
