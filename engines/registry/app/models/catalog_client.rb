class CatalogClient
  include RegistryClient

  def initialize(token)
    payload = JWT.decode(token, public_key, true, { algorithm: 'RS256' })
    @account = payload.first['sub']
    @access = payload.first.fetch('access', [])
    @auth_strategy = nil if @account.blank?
    Rails.logger.info("Got token for '#{self}'")
  end

  def authorized_for_catalog?
    (@access.any? &&
     @access.first.fetch('type', '') == 'registry' && # TODO: better not only check the first 'access'
     @access.first.fetch('name', '') == 'catalog' &&
     @access.first.fetch('actions', []) == ['*'])
  end

  private

  def public_key
    Rails.application.config.registry_private_key.public_key
  end
end
