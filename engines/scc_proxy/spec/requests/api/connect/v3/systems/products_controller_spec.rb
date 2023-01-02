require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

describe Api::Connect::V3::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions) }
  let(:product_sap) { FactoryBot.create(:product, :product_sles_sap, :with_mirrored_repositories, :with_mirrored_extensions) }

  let(:payload) do
    {
      identifier: product.identifier,
      version: product.version,
      arch: product.arch
    }
  end
  let(:payload_byos) do
    {
      identifier: product.identifier,
      version: product.version,
      arch: product.arch,
      email: 'foo',
      token: 'bar'
    }
  end

  describe '#activate' do
    let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }


    context 'when system has hw_info' do
      let(:instance_data) { '<document>{"instanceId": "dummy_instance_data"}</document>' }
      let(:system) { FactoryBot.create(:system, :with_hw_info, instance_data: instance_data) }
      let(:serialized_service_json) do
        V3::ServiceSerializer.new(
          product.service,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end

      let(:serialized_service_sap_json) do
        V3::ServiceSerializer.new(
          product_sap.service,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end

      context 'when system is connected to SCC' do
        let(:system) { FactoryBot.create(:system, :byos, :with_hw_info, instance_data: instance_data) }
        let(:scc_activate_url) { 'https://scc.suse.com/connect/systems/products' }
        let(:subscription_response) do
          {
            id: 4206714,
            regcode: 'bar',
            name: 'SUSE Employee subscription for SUSE Linux Enterprise Server for SAP Applications',
            type: 'internal',
            status: 'ACTIVE',
            starts_at: '2019-03-20T09:48:52.658Z',
            expires_at: '2024-03-20T09:48:52.658Z',
            system_limit: '100',
            systems_count: '156',
            virtual_count: nil,
            product_classes: [
              'AiO',
              '7261',
              'SLE-HAE-X86',
              '7261-BETA',
              'SLE-HAE-X86-BETA',
              'AiO-BETA',
              '7261-ALPHA',
              'SLE-HAE-X86-ALPHA',
              'AiO-ALPHA'
            ],
            product_ids: [
              1959,
              1421
            ],
            skus: [],
            systems: [
              {
                id: 3021957,
                login: 'SCC_foo',
                password: '5ee7273ac6ac4d7f',
                last_seen_at: '2019-03-20T14:01:05.424Z'
              }
            ]
          }
        end

        before do
          allow(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
          allow(plugin_double).to(
            receive(:instance_valid?)
              .and_raise(InstanceVerification::Exception, 'Custom plugin error')
          )
        end

        context 'with a valid registration code' do
          before do
            stub_request(:post, scc_activate_url)
              .to_return(
                status: 201,
                body: '{"id": "bar"}',
                headers: {}
              )
            post url, params: payload_byos, headers: headers
          end

          it 'renders service JSON' do
            expect(response.body).to eq(serialized_service_json)
          end
        end

        context 'with a not valid registration code' do
          before do
            stub_request(:post, scc_activate_url)
              .to_return(
                status: 401,
                body: '{"error": "No product found on SCC for: foo bar x86_64 json api"}',
                headers: {}
              )
            post url, params: payload_byos, headers: headers
          end

          it 'renders an error with exception details' do
            data = JSON.parse(response.body)
            expect(data['error']).to include('No product found on SCC')
            expect(data['error']).not_to include('json api')
          end
        end
      end
    end
  end

  context 'when activating extensions' do
    let(:instance_data) { 'dummy_instance_data' }
    let(:system) do
      FactoryBot.create(
        :system, :with_hw_info, :with_activated_product, product: base_product, instance_data: instance_data
      )
    end
    let(:serialized_service_json) do
      V3::ServiceSerializer.new(
        product.service,
        base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
      ).to_json
    end
    let(:scc_activate_url) { 'https://scc.suse.com/connect/systems/products' }

    before do
      FactoryBot.create(:subscription, product_classes: product_classes)
      stub_request(:post, scc_activate_url)
        .to_return(
          status: 401,
          body: 'bar',
          headers: {}
        )

      post url, params: payload, headers: headers
    end

    context 'when the extension is not free' do
      let(:base_product) { FactoryBot.create(:product, :with_mirrored_repositories) }

      context 'when a suitable subscription is not found' do
        let(:product) do
          FactoryBot.create(
            :product, :with_mirrored_repositories, :extension, free: false, base_products: [base_product]
          )
        end
        let(:product_classes) { [base_product.product_class] }

        it 'reports an error' do
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Instance verification failed: The product is not available for this instance')
          expect(InstanceVerification::Providers::Example).not_to receive(:new)
        end
      end

      context 'when a suitable subscription is found' do
        let(:product) do
          FactoryBot.create(
            :product, :with_mirrored_repositories, :extension, free: false, base_products: [base_product]
          )
        end
        let(:product_classes) { [base_product.product_class, product.product_class] }

        it 'returns service JSON' do
          expect(response.body).to eq(serialized_service_json)
        end
      end
    end

    context 'when the extension is free' do
      let(:base_product) { FactoryBot.create(:product, :with_mirrored_repositories) }
      let(:product) do
        FactoryBot.create(
          :product, :with_mirrored_repositories, :extension, free: true, base_products: [base_product]
        )
      end
      let(:product_classes) { [base_product.product_class] }

      it 'returns service JSON' do
        expect(response.body).to eq(serialized_service_json)
      end
    end


    context 'when the base product subscription is missing' do
      let(:base_product) { FactoryBot.create(:product, :with_mirrored_repositories) }
      let(:product) do
        FactoryBot.create(
          :product, :with_mirrored_repositories, :extension, free: false, base_products: [base_product]
        )
      end
      let(:product_classes) { [] }

      it 'reports an error' do
        data = JSON.parse(response.body)
        expect(data['error']).to eq('Unexpected instance verification error has occurred')
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
