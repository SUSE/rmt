# coding: utf-8
require 'json'
require 'net/http'

CATALOG_API_URL = 'http://127.0.0.1:5000/v2/_catalog'.freeze
AUTH_URL = 'api/registry/authorize'.freeze
CATALOG_SCOPE = 'registry:catalog:*'.freeze
SERVICE = 'SUSE Linux OCI Registry'.freeze

class RegistryCatalogService
  attr_accessor :catalog_api_url

  # We overwrite the public request /v2/_catalog with our endpoint
  # RMT still needs to be able to get the unfiltered _catalog from the registry
  # So we query CATALOG_API_URL (registry catalog) and return the fetched repositories
  # n > 1000 crashes the request to CATALOG_API_URL

  def initialize(url = CATALOG_API_URL)
    @catalog_api_url = url
  end

  # be aware that this takes about 20-25 seconds to be finished if not in cache
  def repos(system, reload: false)
    Rails.cache.fetch(@catalog_api_url, expires_in: 1.hour, force: reload) do
      fetch_registry_repos(system)
    end
  end

  private

  def fetch_registry_repos(system)
    Rails.logger.info('Fetch registry repos')
    response = catalog_token(system)
    catalog_auth_token = JSON.parse(response.body).fetch('token', '')
    response = all_repos(catalog_auth_token)
    JSON.parse(response.body).fetch('repositories', [])
  end

  def catalog_token(system)
    framework = InstanceVerification.provider.name.rpartition('::')[2].downcase
    uri = URI.parse(URI.join("https://registry-#{framework}.susecloud.net", AUTH_URL).to_s)
    catalog_token_params = {
      service: SERVICE,
      account: system.login,
      scope: CATALOG_SCOPE
    }
    uri.query = URI.encode_www_form(catalog_token_params)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    registry_request = Net::HTTP::Get.new(uri.to_s)
    http.request(registry_request)
  end

  def all_repos(auth_token)
    uri = URI.parse(@catalog_api_url)
    # n > 1000 crashes the request to CATALOG_API_URL
    uri.query = URI.encode_www_form({ n: 1000 })
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false
    registry_request = Net::HTTP::Get.new(uri.to_s)
    registry_request['Authorization'] = format("Bearer #{auth_token}")
    response = nil
    time = Benchmark.realtime do
      response = http.request(registry_request)
    end
    Rails.logger.info("… took #{time}")
    response
  end
end
