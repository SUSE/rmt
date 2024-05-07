class Registry::AuthenticatedClient
  include RegistryClient

  attr_reader :auth_strategy

  def initialize(login, password, remote_ip)
    raise Registry::Exceptions::InvalidCredentials.new(message: 'expired credentials', login: login) unless cache_file_exist?(remote_ip, login)

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
    if @systems.present?
      @account = login
      @auth_strategy = :system_credentials
    end
    @auth_strategy
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
