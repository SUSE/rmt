describe Api::Connect::V4::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 4


  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:instance_data) { 'dummy_instance_data' }
  let(:system) { FactoryBot.create(:system, :byos, :with_hw_info, instance_data: instance_data) }

  describe '#deactivate' do
    let(:scc_systems_products_url) { 'https://scc.suse.com/connect/systems/products' }

    context 'an activated non base module' do
      context 'with right credentials' do
        let(:product) do
          FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system, product_type: 'module')
        end
        let(:payload) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch
          }
        end
        let(:serialized_service_json) do
          V3::ServiceSerializer.new(
            product.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        before do
          stub_request(:delete, scc_systems_products_url)
            .to_return(
              status: 200,
              body: '',
              headers: {}
            )
          allow(Rails.logger).to receive(:info)
          delete url, params: payload, headers: headers
        end

        it 'returns a service JSON and successfully deactivate the product' do
          expect(Rails.logger).to(
            have_received(:info).with(
              "Product '#{product.friendly_name}' successfully deactivated from SCC"
            ).once
          )
          expect(response.body).to eq(serialized_service_json)
        end
      end

      context 'when SCC API returns an error' do
        let(:product) do
          FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system, product_type: 'module')
        end
        let(:payload) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch
          }
        end
        let(:serialized_service_json) do
          V3::ServiceSerializer.new(
            product.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        before do
          stub_request(:delete, scc_systems_products_url)
            .to_return(
              status: 422,
              body: "{\"error\": \"Could not de-activate product \'#{product.friendly_name}\'\"}",
              headers: {}
            )
          delete url, params: payload, headers: headers
        end

        it 'reports an error' do
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Could not de-activate product \'SUSE Linux Enterprise Server 15 SP3 x86_64\'')
        end
      end
    end

    context 'an activated base module with right credentials' do
      let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system) }
      let(:payload) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch
        }
      end

      before { delete url, params: payload, headers: headers }

      it 'reports an error' do
        data = JSON.parse(response.body)
        expect(data['error']).to eq("The product \"#{product.name}\" is a base product and cannot be deactivated")
      end
    end
  end
end
