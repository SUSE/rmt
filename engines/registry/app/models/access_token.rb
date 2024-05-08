require 'base32'

# Following Docker distribution token auth specs,
# see docs here: https://github.com/distribution/distribution/blob/main/docs/spec/auth/token.md
class AccessToken
  def initialize(account, service, granted_scopes)
    @account = account
    @service = service # "SUSE Linux OCI Registry"
    @granted_scopes = granted_scopes
  end

  def token
    JWT.encode(claim, private_key, 'RS256', { 'kid' => jwt_kid })
  end

  private

  def claim
    {}.tap do |hash|
      hash['iss']    = 'RMT' # "matching issuer in registry auth token config"
      hash['sub']    = @account
      hash['aud']    = @service
      hash['exp']    = Time.now.getlocal.to_i + (5 * 60) # expires at
      hash['nbf']    = Time.now.getlocal.to_i # not before
      hash['iat']    = Time.now.getlocal.to_i # issued at
      hash['jti']    = Base64.urlsafe_encode64(SecureRandom.uuid, padding: false)
      hash['access'] = @granted_scopes
      Rails.logger.debug { "Returning token for claim: #{hash}" }
    end
  end

  # Returns the ID of the key which was to used to sign the token.
  def jwt_kid
    sha256 = Digest::SHA256.new
    sha256.update(private_key.public_key.to_der)
    payload = StringIO.new(sha256.digest).read(30)
    Base32.encode(payload).chars.each_slice(4).with_object([]) do |slice, mem|
      mem << slice.join
      mem
    end.join(':')
  end

  def private_key
    @private_key ||= Rails.application.config.registry_private_key
  end
end
