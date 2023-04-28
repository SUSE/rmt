require 'json'

module SccSuma
  REPOSITORY_URL = 'https://scc.suse.com/suma/'.freeze

  class SccSumaController < ::ApplicationController
    before_action :is_valid?, only: %w[get_scc_client]
    before_action :get_scc_client, only: %w[unscoped_products get_list]

    def unscoped_products
      render status: :ok, json: { result: @scc_api_client.list_products_unscoped.to_json }
    end

    def get_list
      render status: :ok, json: { result: [] }
    end

    def product_tree
      json_product_tree = get_product_tree_json
      render status: :ok, json: { result: json_product_tree }
    end

    def get_scc_client
      @scc_api_client = SUSE::Connect::Api.new(
        Settings.scc.username,
        Settings.scc.password
      )
    end

    protected

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
      @product_tree_file = get_file_reference

      download_file_from_scc unless cache_is_valid?

      JSON.parse(File.open(@product_tree_file.local_path).read)
    end

    def get_file_reference
      tmp_dir = Rails.root.join('tmp')
      downloading_paths = {
        base_url: URI.join(REPOSITORY_URL),
        base_dir: tmp_dir,
        cache_dir: tmp_dir
      }

      RMT::Mirror::FileReference.new(relative_path: 'product_tree.json', **downloading_paths)
    end

    def download_file_from_scc
      downloader = RMT::Downloader.new(logger: logger, track_files: false)
      logger.info _('Downloading SUSE Manager product tree to %{dir}') % { dir: tmp_dir }
      downloader.download_multi([@product_tree_file])
    end

    def cache_is_valid?
      return false unless File.exist(@product_tree_file.local_path)

      File.new(@product_tree_file.local_path).ctime > 1.day.ago
    end
  end
end
