require 'base64'
require 'json'

module SccSumaApi
  REPOSITORY_URL = 'https://scc.suse.com/suma/'.freeze
  CACHED_PRODUCT_TREE_JSON = '/usr/share/rmt/public/suma/product_tree.json'.freeze


  class SccSumaApiController < ::ApplicationController
    before_action :is_valid?, only: %w[unscoped_products]

    def unscoped_products
      update_cache unless cache_is_valid?

      unscoped_products_json = File.read(@unscoped_products_path)
      render status: :ok, json: JSON.parse(unscoped_products_json)
    end

    def list
      render status: :ok, json: []
    end

    def product_tree
      render status: :ok, json: product_tree_json
    end

    protected

    def scc_client
      @scc_api_client = SUSE::Connect::Api.new(
        Settings.scc.username,
        Settings.scc.password
      )
    end

    def is_valid?
      instance_data = Base64.decode64(request.headers['X-Instance-Data'].to_s)
      product_hash = {
        identifier: request.headers['X-INSTANCE-IDENTIFIER'],
        version: request.headers['X-INSTANCE-VERSION'],
        arch: request.headers['X-INSTANCE-ARCH']
      }
      verification_provider = InstanceVerification.provider.new(
        logger,
        request,
        product_hash,
        instance_data
        )
      # check auth for registered BYOS systems
      iid = verification_provider.parse_instance_data
      systems_found = System.find_by(system_token: iid['instanceId'], proxy_byos: true)

      raise 'Unspecified error' unless systems_found.present? || verification_provider.instance_valid?
    end

    def product_tree_json
      product_tree_file_path = CACHED_PRODUCT_TREE_JSON
      unless File.exist?(product_tree_file_path)
        product_tree_file_path.nil?
        download_file_from_scc
        product_tree_file_path = @product_tree_file.local_path
      end

      JSON.parse(File.read(product_tree_file_path))
    end

    def download_file_from_scc
      tmp_dir = Rails.root.join('tmp')
      downloading_paths = {
        base_url: URI.join(REPOSITORY_URL),
        base_dir: tmp_dir,
        cache_dir: tmp_dir
      }
      @product_tree_file = RMT::Mirror::FileReference.new(relative_path: 'product_tree.json', **downloading_paths)

      downloader = RMT::Downloader.new(logger: logger, track_files: false)
      logger.info _('Downloading SUSE Manager product tree to %{dir}') % { dir: tmp_dir }
      downloader.download_multi([@product_tree_file])
    end

    def cache_is_valid?
      @unscoped_products_path = Rails.root.join('tmp/unscoped_products.json')

      return false unless File.exist?(@unscoped_products_path)

      File.new(@unscoped_products_path).ctime > 1.day.ago
    end

    def update_cache
      scc_client
      unscoped_products_json = @scc_api_client.list_products_unscoped.to_json
      File.write(@unscoped_products_path, unscoped_products_json)
    end
  end
end
