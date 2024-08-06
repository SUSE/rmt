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

  describe '#activate' do
    let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

    context 'when the system is byos' do
      context "when system doesn't have hw_info" do
        let(:system) { FactoryBot.create(:system, :byos) }

        before do
          stub_request(:post, 'https://scc.suse.com/connect/systems/products')
            .to_return(
              status: 201,
              body: { ok: 'ok' }.to_json,
              headers: {}
            )
        end

        it 'class instance verification provider' do
          expect(InstanceVerification::Providers::Example).to receive(:new)
            .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, nil).and_call_original
          allow(File).to receive(:directory?)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
          post url, params: payload, headers: headers
        end
      end

      context 'when system has hw_info' do
        let(:instance_data) { 'dummy_instance_data' }
        let(:system) { FactoryBot.create(:system, :with_system_information, instance_data: instance_data) }
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

        let(:serialized_service_byos_json) do
          V3::ServiceSerializer.new(
            product_sap.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        context 'when verification provider returns false' do
          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
            expect(plugin_double).to receive(:instance_valid?).and_return(false)
            post url, params: payload, headers: headers
          end

          it 'renders an error' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unexpected instance verification error has occurred')
          end
        end

        context 'when verification provider raises an unhandled exception' do
          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
            expect(plugin_double).to receive(:instance_valid?).and_raise('Custom plugin error')
            post url, params: payload, headers: headers
          end

          it 'renders an error with exception details' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unexpected instance verification error has occurred')
          end
        end

        context 'when verification provider raises an instance verification exception' do
          let(:scc_activate_url) { 'https://scc.suse.com/connect/systems/products' }

          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
            expect(plugin_double).to receive(:instance_valid?).and_raise(InstanceVerification::Exception, 'Custom plugin error')

            post url, params: payload, headers: headers
          end

          it 'renders an error with exception details' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Instance verification failed: Custom plugin error')
          end
        end
      end
    end

    context 'when the system is payg' do
      context "when system doesn't have hw_info" do
        let(:system) { FactoryBot.create(:system) }

        it 'class instance verification provider' do
          expect(InstanceVerification::Providers::Example).to receive(:new)
            .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, nil).and_call_original
          allow(File).to receive(:directory?)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
          post url, params: payload, headers: headers
        end
      end

      context 'when system has hw_info' do
        let(:instance_data) { 'dummy_instance_data' }
        let(:system) { FactoryBot.create(:system, :with_system_information, instance_data: instance_data) }
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

        context 'when verification provider returns false' do
          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
            expect(plugin_double).to receive(:instance_valid?).and_return(false)
            post url, params: payload, headers: headers
          end

          it 'renders an error' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unexpected instance verification error has occurred')
          end
        end

        context 'when verification provider raises an unhandled exception' do
          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
            expect(plugin_double).to receive(:instance_valid?).and_raise('Custom plugin error')
            post url, params: payload, headers: headers
          end

          it 'renders an error with exception details' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unexpected instance verification error has occurred')
          end
        end

        context 'when verification provider raises an instance verification exception' do
          let(:scc_activate_url) { 'https://scc.suse.com/connect/systems/products' }

          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
            expect(plugin_double).to receive(:instance_valid?).and_raise(InstanceVerification::Exception, 'Custom plugin error')

            post url, params: payload, headers: headers
          end

          it 'renders an error with exception details' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Instance verification failed: Custom plugin error')
          end
        end
      end

      context 'when activating extensions with errors' do
        let(:instance_data) { 'dummy_instance_data' }
        let(:system) do
          FactoryBot.create(
            :system, :byos, :with_system_information, :with_activated_product, product: base_product, instance_data: instance_data
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
        let(:payload) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch,
            instance_data: 'dummy_instance_data',
            proxy_byos_mode: :payg,
            hwinfo:
            {
              hostname: 'test',
              cpus: '1',
              sockets: '1',
              hypervisor: 'Xen',
              arch: 'x86_64',
              uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
              cloud_provider: 'amazon'
            }
          }
        end

        before do
          allow(InstanceVerification::Providers::Example).to receive(:new)
            .with(nil, nil, nil, instance_data).and_return(plugin_double)
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
            end
          end

          context 'when a suitable subscription is found' do
            let(:product) do
              FactoryBot.create(
                :product, :with_mirrored_repositories, :extension, free: false, base_products: [base_product]
              )
            end
            let(:product_classes) { [base_product.product_class, product.product_class] }
            let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

            it 'returns error when SCC call fails' do
              data = JSON.parse(response.body)
              expect(data['error']).to eq('Instance verification failed: The product is not available for this instance')
            end
          end
        end
      end

      context 'when activating extensions without errors' do
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
        let(:payload) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch,
            instance_data: 'dummy_instance_data',
            hwinfo:
            {
              hostname: 'test',
              cpus: '1',
              sockets: '1',
              hypervisor: 'Xen',
              arch: 'x86_64',
              uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
              cloud_provider: 'amazon'
            }
          }
        end

        before do
          allow(InstanceVerification::Providers::Example).to receive(:new)
            .with(nil, nil, nil, instance_data).and_return(plugin_double)
          allow(plugin_double).to receive(:parse_instance_data).and_return({ InstanceId: 'foo' })

          FactoryBot.create(:subscription, product_classes: product_classes)
          stub_request(:post, scc_activate_url)
            .to_return(
              status: 201,
              body: {}.to_json,
              headers: {}
            )
          # stub the fake announcement call PAYG has to do to SCC
          # to create the system before activate product (and skip validation)
          stub_request(:post, 'https://scc.suse.com/connect/subscriptions/systems')
            .to_return(status: 201, body: { ok: 'OK' }.to_json, headers: {})

          post url, params: payload, headers: headers
        end

        context 'when a suitable subscription is found' do
          let(:base_product) { FactoryBot.create(:product, :with_mirrored_repositories) }

          let(:product) do
            FactoryBot.create(
              :product, :with_mirrored_repositories, :extension, free: false, base_products: [base_product]
            )
          end
          let(:product_classes) { [base_product.product_class, product.product_class] }
          let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

          it 'returns error when SCC call succeeds' do
            expect(response.body).to eq(serialized_service_json)
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
      end
    end

    context 'when the system is hybrid' do
      context "when system doesn't have hw_info" do
        let(:system) { FactoryBot.create(:system, :hybrid) }

        it 'class instance verification provider' do
          expect(InstanceVerification::Providers::Example).to receive(:new)
            .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, nil).and_call_original
          allow(File).to receive(:directory?)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
          post url, params: payload, headers: headers
        end
      end

      context 'when system has hw_info' do
        let(:instance_data) { 'dummy_instance_data' }
        let(:system) { FactoryBot.create(:system, :hybrid, :with_system_information, instance_data: instance_data) }
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

        context 'when verification provider returns false' do
          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
            expect(plugin_double).to receive(:instance_valid?).and_return(false)
            post url, params: payload, headers: headers
          end

          it 'renders an error' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unexpected instance verification error has occurred')
          end
        end

        context 'when verification provider raises an unhandled exception' do
          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
            expect(plugin_double).to receive(:instance_valid?).and_raise('Custom plugin error')
            post url, params: payload, headers: headers
          end

          it 'renders an error with exception details' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unexpected instance verification error has occurred')
          end
        end
      end
    end

    context 'when activating extensions with errors' do
      let(:instance_data) { 'dummy_instance_data' }
      let(:system) do
        FactoryBot.create(
          :system, :hybrid, :with_system_information, :with_activated_product, product: base_product, instance_data: instance_data
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
      let(:payload) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch,
          instance_data: 'dummy_instance_data',
          proxy_byos_mode: :hybrid,
          hwinfo:
          {
            hostname: 'test',
            cpus: '1',
            sockets: '1',
            hypervisor: 'Xen',
            arch: 'x86_64',
            uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
            cloud_provider: 'amazon'
          }
        }
      end

      before do
        allow(InstanceVerification::Providers::Example).to receive(:new)
          .with(nil, nil, nil, instance_data).and_return(plugin_double)
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
          end
        end

        context 'when a suitable subscription is found' do
          let(:product) do
            FactoryBot.create(
              :product, :with_mirrored_repositories, :extension, free: false, base_products: [base_product]
              )
          end
          let(:product_classes) { [base_product.product_class, product.product_class] }
          let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

          it 'returns error when SCC call fails' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Instance verification failed: The product is not available for this instance')
          end
        end
      end
    end

    context 'when activating extensions without errors' do
      let(:instance_data) { 'dummy_instance_data' }
      let(:system) do
        FactoryBot.create(
          :system, :hybrid, :with_system_information, :with_activated_product, product: base_product, instance_data: instance_data
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
      let(:payload) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch,
          instance_data: 'dummy_instance_data',
          proxy_byos_mode: :hybrid,
          hwinfo:
          {
            hostname: 'test',
            cpus: '1',
            sockets: '1',
            hypervisor: 'Xen',
            arch: 'x86_64',
            uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
            cloud_provider: 'amazon'
          }
        }
      end

      before do
        allow(InstanceVerification::Providers::Example).to receive(:new)
          .with(nil, nil, nil, instance_data).and_return(plugin_double)
        allow(plugin_double).to receive(:parse_instance_data).and_return({ InstanceId: 'foo' })

        FactoryBot.create(:subscription, product_classes: product_classes)
        stub_request(:post, scc_activate_url)
          .to_return(
            status: 201,
            body: {}.to_json,
            headers: {}
          )
        # stub the fake announcement call PAYG has to do to SCC
        # to create the system before activate product (and skip validation)
        stub_request(:post, 'https://scc.suse.com/connect/subscriptions/systems')
          .to_return(status: 201, body: { ok: 'OK' }.to_json, headers: {})

        post url, params: payload, headers: headers
      end

      context 'when a suitable subscription is found' do
        let(:base_product) { FactoryBot.create(:product, :with_mirrored_repositories) }

        let(:product) do
          FactoryBot.create(
            :product, :with_mirrored_repositories, :extension, free: false, base_products: [base_product]
            )
        end
        let(:product_classes) { [base_product.product_class, product.product_class] }
        let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

        it 'returns error when SCC call succeeds' do
          expect(response.body).to eq(serialized_service_json)
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
    end
  end

  describe '#upgrade' do
    subject { response }

    let(:system) { FactoryBot.create(:system) }
    let(:request) { put url, headers: headers, params: payload }
    let!(:old_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system) }
    let(:payload) do
      {
        identifier: new_product.identifier,
        version: new_product.version,
        arch: new_product.arch
      }
    end

    before { request }

    context "when migration target base product doesn't have an activated successor/predecessor" do
      let(:new_product) { FactoryBot.create(:product, :with_mirrored_repositories) }

      it 'HTTP response code is 422' do
        expect(response).to have_http_status(422)
      end

      it 'renders an error' do
        data = JSON.parse(response.body)
        expect(data['error']).to eq('Migration target not allowed on this instance type')
      end
    end

    context 'when migration target base product has a different identifier' do
      let(:new_product) do
        FactoryBot.create(
          :product, :with_mirrored_repositories,
          identifier: old_product.identifier + '-foo', predecessors: [ old_product ]
        )
      end

      it 'HTTP response code is 422' do
        expect(response).to have_http_status(422)
      end

      it 'renders an error' do
        data = JSON.parse(response.body)
        expect(data['error']).to eq('Migration target not allowed on this instance type')
      end
    end

    context 'when migration target base product has the same identifier' do
      let(:new_product) do
        FactoryBot.create(
          :product, :with_mirrored_repositories, identifier: old_product.identifier,
          version: '999', predecessors: [ old_product ]
        )
      end

      it 'HTTP response code is 201' do
        expect(response).to have_http_status(201)
      end

      it "doesn't render an error" do
        data = JSON.parse(response.body)
        expect(data).not_to have_key('error')
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
