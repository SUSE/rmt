class Registry::CatalogClient
  include RegistryClient

  def initialize(token)
    payload = JWT.decode(token, public_key, true, { algorithm: 'RS256' })
    @account = payload.first['sub']
    @access = payload.first.fetch('access', [])
    @auth_strategy = :anonymous if @account.blank?
    Rails.logger.info("Got token for '#{self}'")
  end

  def auth_strategy
    return @auth_strategy if @auth_strategy

    @auth_strategy = :anonymous unless secrets_credentials? || organization_credentials? || systems_credentials? || regcode?
    @auth_strategy
  end

  def authorized_for_catalog?
    (@access.any? &&
     @access.first.fetch('type', '') == 'registry' && # TODO: better not only check the first 'access'
     @access.first.fetch('name', '') == 'catalog' &&
     @access.first.fetch('actions', []) == ['*'])
  end

  def anonymous?
    auth_strategy == :anonymous
  end

  def secrets_credentials?
    return @auth_strategy == :secrets_credentials if @auth_strategy

    if registry_credentials.any? { |c| c[:login] == @account }
      @auth_strategy = :secrets_credentials
      true
    end
  end

  def organization_credentials?
    return @auth_strategy == :organization_credentials if @auth_strategy

    org_credential = OrganizationCredential.find_by(username: @account)
    if org_credential
      @organization = org_credential.organization
      @auth_strategy = :organization_credentials
      true
    end
  end

  def systems_credentials?
    return @auth_strategy == :system_credentials if @auth_strategy

    @systems = System.where(login: @account)
    if @systems.present?
      @auth_strategy = :system_credentials
      true
    end
  end

  def regcode?
    return @auth_strategy == :regcode if @auth_strategy

    @subscription = Subscription.find_by(regcode: @account)
    if @subscription.present?
      @auth_strategy = :regcode
      true
    end
  end

  private

  def public_key
    OpenSSL::X509::Certificate.new(CREDENTIALS.dig(:registry, :certificate) || '').public_key
  end
end
