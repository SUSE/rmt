class Registry::CatalogClient
  include RegistryClient

  def initialize(token)
    payload = JWT.decode(token, public_key, true, { algorithm: 'RS256' })
    @account = payload.first['sub']
    @access = payload.first.fetch('access', [])
    @auth_strategy = nil if @account.blank?
    Rails.logger.info("Got token for '#{self}'")
  end

  def auth_strategy
    return @auth_strategy if @auth_strategy

    @auth_strategy = nil unless systems_credentials?
    @auth_strategy
  end

  def authorized_for_catalog?
    (@access.any? &&
     @access.first.fetch('type', '') == 'registry' && # TODO: better not only check the first 'access'
     @access.first.fetch('name', '') == 'catalog' &&
     @access.first.fetch('actions', []) == ['*'])
  end

  def systems_credentials?
    return @auth_strategy == :system_credentials if @auth_strategy

    @systems = System.where(login: @account)
    if @systems.present?
      @auth_strategy = :system_credentials
      true
    end
  end

  private

  def public_key
    OpenSSL::X509::Certificate.new(CREDENTIALS.dig(:registry, :certificate) || '').public_key
  end
end
