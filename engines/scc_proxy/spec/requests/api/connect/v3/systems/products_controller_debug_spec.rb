require 'rails_helper'

describe Api::Connect::V3::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions) }
  let(:product_sap) { FactoryBot.create(:product, :product_sles_sap, :with_mirrored_repositories, :with_mirrored_extensions) }
  let(:instance_data) { '<instance_data/>' }

  let(:payload) do
    {
      identifier: product.identifier,
      version: product.version,
      arch: product.arch,
      instance_data: instance_data,
      hwinfo:
        {
          hostname: 'super_test',
          cpus: '1',
          sockets: '1',
          hypervisor: 'Xen',
          arch: 'x86_64',
          uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
          cloud_provider: 'amazon'
        }
    }
  end

  context 'when activating extensions' do
    let(:instance_data) { 'dummy_instance_data' }
    let(:system) do
      FactoryBot.create(
        :system, :with_system_information, :with_activated_product, product: base_product, instance_data: instance_data
      )
    end
    let(:serialized_service_json) do
      V3::ServiceSerializer.new(
        product.service,
        base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
      ).to_json
    end
    let(:scc_activate_url) { 'https://scc.suse.com/connect/systems/products' }
    let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

    before do
      allow(InstanceVerification::Providers::Example).to receive(:new)
        .with(nil, nil, nil, 'dummy_instance_data').and_return(plugin_double)
      allow(plugin_double).to receive(:parse_instance_data).and_return({ InstanceId: 'foo' })
      FactoryBot.create(:subscription, product_classes: product_classes)
      stub_request(:post, scc_activate_url)
        .to_return(
          status: 401,
          body: { error: 'Instance verification failed: The product is not available for this instance' }.to_json,
          headers: {}
        )
      # stub the fake announcement call PAYG has to do to SCC
      # to create the system before activate product (and skip validation)
      stub_request(:post, 'https://scc.suse.com/connect/subscriptions/systems')
        .to_return(status: 201, body: { ok: 'OK' }.to_json, headers: {})

      post url, params: payload, headers: headers
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
