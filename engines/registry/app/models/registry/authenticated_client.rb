class Registry::AuthenticatedClient
  include RegistryClient

  def initialize(login, password, remote_ip)
    raise Registry::Exceptions::InvalidCredentials.new(message: 'expired credentials', login: login) unless cache_file_exist?(remote_ip, login)

    raise Registry::Exceptions::InvalidCredentials.new(login: login) unless authenticate_by_system_credentials(login, password)

    Rails.logger.info("Authenticated '#{self}'")
  end

  private

  def authenticate_by_system_credentials(login, password)
    # TODO: add system_token
    # that would imply that the DB query should return ONE record
    # not multiple systems
    # that change is not small and should be done in a different PR
    @systems = System.get_by_credentials(login, password)
    @account = login if @systems.present?
  end

  def cache_file_exist?(remote_ip, login)
    registry_cache_key = [remote_ip, login].join('-')
    registry_cache_path = File.join(cache_config['REGISTRY_CLIENT_CACHE_DIRECTORY'], registry_cache_key)
    File.exist?(registry_cache_path)
  end

  def cache_config
    cache_config_data = {}
    File.open(Rails.application.config.cache_config_file, 'r') do |cache_config_file|
      cache_config_file.each_line do |line|
        line_data = line.split(/=|\n/)
        cache_config_data[line_data[0]] = line_data[1]
      end
    end
    cache_config_data
  end
end
