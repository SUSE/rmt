require 'json'

module SccSuma
  REPOSITORY_URL = 'https://scc.suse.com/suma/'.freeze
  CACHED_PRODUCT_TREE_JSON = '/usr/share/rmt/public/suma/product_tree.json'.freeze


  class SccSumaController < ::ApplicationController
    before_action :is_valid?, only: %w[unscoped_products]

    def unscoped_products
      update_cache unless cache_is_valid?

      unscoped_products_json = File.open(@unscoped_products_path).read
      render status: :ok, json: { result: JSON.parse(unscoped_products_json) }
    end

    def get_list
      render status: :ok, json: { result: [] }
    end

    def product_tree
      render status: :ok, json: { result: get_product_tree_json }
    end

    protected

    def get_scc_client
      @scc_api_client = SUSE::Connect::Api.new(
        Settings.scc.username,
        Settings.scc.password
      )
    end

    def is_valid?
      verification_provider = InstanceVerification.provider.new(
        logger,
        request,
        params.permit(:identifier, :version, :arch, :release_type).to_h,
        params[:metadata]
      )
      raise 'Unspecified error' unless verification_provider.instance_valid?
    end

    def get_product_tree_json
      product_tree_file_path = CACHED_PRODUCT_TREE_JSON
      unless File.exist?(product_tree_file_path)
        product_tree_file_path.nil?
        download_file_from_scc
        product_tree_file_path = @product_tree_file.local_path
      end

      return JSON.parse(File.open(product_tree_file_path).read)
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
      @unscoped_products_path = File.join(Rails.root.join('tmp'), '/unscoped_products.json')

      return false unless File.exist?(@unscoped_products_path)

      File.new(@unscoped_products_path).ctime > 1.day.ago
    end

    def update_cache
      get_scc_client
      unscoped_products_json = @scc_api_client.list_products_unscoped.to_json
      File.open(@unscoped_products_path, 'w') {|f| f.write(unscoped_products_json)}
    end
  end
end
