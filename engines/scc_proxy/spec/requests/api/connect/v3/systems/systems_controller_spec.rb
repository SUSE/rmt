describe Api::Connect::V3::Systems::SystemsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { '/connect/systems' }
  let(:headers) { auth_header.merge(version_header) }
  let(:instance_data) { 'dummy_instance_data' }
  let(:system) { FactoryBot.create(:system, :byos, :with_hw_info, instance_data: instance_data) }

  describe '#deactivate' do
    let(:scc_systems_url) { 'https://scc.suse.com/connect/systems' }
    let(:scc_systems_products_url) { 'https://scc.suse.com/connect/systems/products' }

    context 'a system' do
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
          stub_request(:delete, scc_systems_url)
            .to_return(
              status: 204,
              body: '',
              headers: {}
            )
          allow(Rails.logger).to receive(:info)
          delete url, params: payload, headers: headers
        end

        it 'returns a service JSON and successfully deactivate the product' do
          expect(Rails.logger).to have_received(:info).with('System successfully deregistered from SCC').once
        end
      end
    end

    context 'a system with error from SCC API for product' do
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

      before do
        stub_request(:delete, scc_systems_products_url)
          .to_return(
            status: 422,
            body: "{\"error\": \"No product found on SCC for: #{product.name} #{product.version} #{product.arch}\"}",
            headers: {}
          )
        allow(Rails.logger).to receive(:info)
        delete url, params: payload, headers: headers
      end

      it 'reports an error' do
        message = 'Could not de-activate product '\
          "'#{product.friendly_name}', error: No product found on SCC for: "\
          "#{product.name} #{product.version} #{product.arch} 422"
        expect(Rails.logger).to have_received(:info).with(message).once
        data = JSON.parse(response.body)
        expect(data['error']).to eq("No product found on SCC for: #{product.name} #{product.version} #{product.arch}")
      end
    end

    context 'a system with error from SCC API' do
      let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system) }
      let(:payload) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch
        }
      end

      before do
        stub_request(:delete, scc_systems_url)
          .to_return(
            status: 422,
            body: '{"error": "Oh oh, something went wrong"}',
            headers: {}
          )
        allow(Rails.logger).to receive(:info)
        delete url, params: payload, headers: headers
      end

      it 'reports an error' do
        expect(Rails.logger).to(
          have_received(:info).with(
            "Could not de-activate system #{system.login}, error: Oh oh, something went wrong 422"
).once
        )
        data = JSON.parse(response.body)
        expect(data['error']).to eq('Oh oh, something went wrong')
      end
    end
  end
end
