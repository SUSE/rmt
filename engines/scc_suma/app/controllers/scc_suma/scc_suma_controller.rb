module SccSuma
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
      render status: :ok, json: { result: 'some_result' }
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
  end
end
