class Registry::AuthenticatedClient
  include RegistryClient

  attr_reader :auth_strategy

  def initialize(login, password, remote_ip)
    authenticate_by_system_credentials(login, password, remote_ip)
    if @auth_strategy
      Rails.logger.info("Authenticated '#{self}'")
    else
      raise Registry::Exceptions::InvalidCredentials.new(login: login)
    end
  end

  private

  def authenticate_by_system_credentials(login, password, remote_ip)
    @systems = System.get_by_credentials(login, password)
    expiration_value = Settings[:registry].try(:token_expiration) || 8.hours.to_i
    cache_key = [remote_ip, login].join('-')
    registry_cache_path = Rails.root.join('tmp', 'registry', 'cache', cache_key)
    cache_created = File.exist?(registry_cache_path)
    time_has_not_expired = @systems.any? { |system| system.last_seen_at > expiration_value.seconds.ago }
    if time_has_not_expired && cache_created
      @account = login
      @auth_strategy = :system_credentials
    end
    File.delete(registry_cache_path) unless time_has_not_expired
    @auth_strategy
  end
end
