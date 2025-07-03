require 'base64'
require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
describe Api::Connect::V3::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions) }
  let(:product_sap) { FactoryBot.create(:product, :product_sles_sap, :with_mirrored_repositories, :with_mirrored_extensions) }
  let(:scc_activate_url) { 'https://scc.suse.com/connect/systems/products' }
  let(:expected_payload) do
    {
      identifier: product.identifier,
      version: product.version,
      arch: product.arch
    }
  end
  let(:payload) do
    {
      identifier: product.identifier,
      version: product.version,
      arch: product.arch,
      token: 'super_reg_code'
    }
  end

  describe '#activate' do
    let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

    after { FileUtils.rm_rf(File.dirname(Rails.application.config.registry_cache_dir)) }

    context 'when the system is byos' do
      context "when system doesn't have hw_info" do
        let(:system) { FactoryBot.create(:system, :byos, system_token: 'foo', instance_data: 'dummy_instance_data') }

        before do
          stub_request(:post, 'https://scc.suse.com/connect/systems/products')
            .to_return(
              status: 201,
              body: { ok: 'ok' }.to_json,
              headers: {}
            )
        end

        it 'class instance verification provider' do
          expect(InstanceVerification::Providers::Example).to receive(:new).at_least(:once).and_return(plugin_double)
          allow(plugin_double).to receive(:instance_valid?).and_raise(InstanceVerification::Exception, 'FOO')
          allow(plugin_double).to receive(:allowed_extension?).and_return(true)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
          post url, params: payload, headers: headers
        end
      end

      context "when system doesn't have hw_info and cache is inactive" do
        let(:system) { FactoryBot.create(:system, :byos, pubcloud_reg_code: Base64.strict_encode64('super_token')) }

        before do
          stub_request(:post, 'https://scc.suse.com/connect/systems/products')
            .to_return(
              status: 201,
              body: { ok: 'ok' }.to_json,
              headers: {}
            )
        end

        it 'class instance verification provider' do
          expect(InstanceVerification::Providers::Example).to receive(:new).at_least(:once).and_return(plugin_double)
          allow(plugin_double).to receive(:instance_valid?).and_raise(InstanceVerification::Exception, 'FOO')
          allow(plugin_double).to receive(:instance_identifier).and_return('foo')
          allow(plugin_double).to receive(:allowed_extension?).and_return(true)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
          post url, params: payload, headers: headers
        end
      end

      context 'when system has hw_info' do
        let(:instance_data) { 'dummy_instance_data' }
        let(:system) { FactoryBot.create(:system, :byos, :with_system_information, instance_data: instance_data) }
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
          let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

          before do
            stub_request(:post, scc_activate_url)
            .to_return(
              status: 200,
              body: { error: 'Unexpected instance verification error has occurred' }.to_json,
              headers: {}
              )
            allow(InstanceVerification::Providers::Example).to receive(:new).and_return(plugin_double)
            allow(plugin_double).to receive(:instance_identifier).and_return('foo')
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)
            allow(plugin_double).to receive(:instance_valid?).and_return(false)
            post url, params: payload, headers: headers
          end

          it 'renders an error' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unexpected instance verification error has occurred')
          end
        end

        context 'when verification provider raises an unhandled exception' do
          before do
            expect(InstanceVerification::Providers::Example).to receive(:new).and_return(plugin_double).at_least(:once)
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)
            allow(plugin_double).to receive(:instance_valid?).and_raise('not expected')
            allow(plugin_double).to receive(:instance_identifier).and_return('foo')
            allow(InstanceVerification).to receive(:set_cache_inactive).and_return(nil)
            stub_request(:post, scc_activate_url)
            .to_return(
              status: 422,
              body: { error: 'Unexpected instance verification error has occurred' }.to_json,
              headers: {}
            )

            post url, params: payload, headers: headers
          end

          it 'renders an error with exception details' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unexpected instance verification error has occurred')
          end
        end
      end
    end

    context 'when the system is payg' do
      context "when system doesn't have hw_info" do
        let(:system) { FactoryBot.create(:system, :payg) }

        it 'class instance verification provider' do
          expect(InstanceVerification::Providers::Example).to receive(:new)
            .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), expected_payload, nil).and_call_original.at_least(:once)
          expect(InstanceVerification::Providers::Example).to receive(:new)
            .with(nil, nil, nil, nil).and_call_original.at_least(:once)
          allow(File).to receive(:directory?)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
          post url, params: payload, headers: headers
        end
      end

      context 'when system has hw_info' do
        let(:instance_data) { 'dummy_instance_data' }
        let(:system) { FactoryBot.create(:system, :payg, :with_system_information, instance_data: instance_data) }
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
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), expected_payload, instance_data).and_return(plugin_double).at_least(:once)
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(nil, nil, nil, instance_data).and_call_original.at_least(:once)
            expect(plugin_double).to receive(:instance_valid?).and_raise('ERROR')
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)
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
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), expected_payload, instance_data).and_return(plugin_double).at_least(:once)
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(nil, nil, nil, instance_data).and_call_original.at_least(:once)
            expect(plugin_double).to receive(:instance_valid?).and_raise('Custom plugin error')
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)
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
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), expected_payload, instance_data).and_return(plugin_double).at_least(:once)
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(nil, nil, nil, instance_data).and_call_original.at_least(:once)
            expect(plugin_double).to receive(:instance_valid?).and_raise(InstanceVerification::Exception, 'Custom plugin error')
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)
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
            :system, :payg, :with_system_information, :with_activated_product, product: base_product, instance_data: instance_data
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
        let(:scc_response_body) do
          {
            id: 1234567,
            login: 'SCC_3b336b126db1503a9513a14e92a6a62e',
            password: '24f057b7941e80f9cf2d51e16e8af2d6'
          }.to_json
        end

        before do
          allow(InstanceVerification::Providers::Example).to receive(:new).and_return(plugin_double)
          allow(plugin_double).to receive(:instance_identifier).and_return('foo')
          allow(plugin_double).to receive(:parse_instance_data).and_return({ InstanceId: 'foo' })
          allow(plugin_double).to receive(:allowed_extension?).and_return(true)
          allow(plugin_double).to receive(:add_on).and_return(nil)

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
            .to_return(status: 201, body: scc_response_body, headers: {})

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

            it 'de-registers system from SCC and reports an error' do
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
            :system,
            :payg,
            :with_system_information,
            :with_activated_product,
            product: base_product,
            instance_data: instance_data,
            pubcloud_reg_code: Base64.strict_encode64('super_token_different')
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
        let(:payload_token) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch,
            instance_data: 'dummy_instance_data',
            proxy_byos_mode: system.proxy_byos_mode,
            token: 'super_token',
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

        let(:scc_response_body) do
          {
            id: 42,
            login: 'SCC_3b336b126db1503a9513a14e92a6a62e',
            password: '24f057b7941e80f9cf2d51e16e8af2d6'
          }.to_json
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
          let(:scc_annouce_body) do
            {
              hostname: system.hostname,
              hwinfo: JSON.parse(system.system_information),
              byos_mode: 'hybrid',
              login: system.login,
              password: system.password
            }
          end
          let(:scc_announce_headers) do
            {
              Accept: 'application/json,application/vnd.scc.suse.com.v4+json',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              Authorization: 'Token token=super_token',
              'Content-Type' => 'application/json',
              'User-Agent' => 'Ruby'
            }
          end
          let(:cache_entry) do
            "#{Base64.strict_encode64(payload_token[:token])}-foo-#{product.product_class}"
          end
          let(:active_cache_entry) { cache_entry + '-active' }
          let(:headers) { auth_header.merge('X-Instance-Data' => 'dummy_instance_data') }

          before do
            allow(InstanceVerification::Providers::Example).to receive(:new).and_return(plugin_double)
            allow(plugin_double).to receive(:instance_identifier).and_return('foo')
            allow(plugin_double).to receive(:parse_instance_data).and_return({ InstanceId: 'foo' })
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)

            # allow(InstanceVerification).to receive(:update_cache).with("127.0.0.1-#{system.login}-#{product.id}", 'payg')
            allow(InstanceVerification).to receive(:get_cache_entries).and_return(
              [File.join(Rails.application.config.repo_hybrid_cache_dir, cache_entry)]
            )
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
              .with({ headers: scc_announce_headers, body: scc_annouce_body.to_json })
              .to_return(status: 201, body: scc_response_body, headers: {})

            # expect(InstanceVerification).to receive(:update_cache).with(cache_entry, 'hybrid')
            expect(InstanceVerification).to receive(:update_cache).with(active_cache_entry, 'hybrid', registry: false)
            headers['X-Instance-Data'] = instance_data
            post url, params: payload_token, headers: headers
          end

          context 'when regcode is provided' do
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

          before do
            allow(InstanceVerification::Providers::Example).to receive(:new)
              .and_return(plugin_double)
            allow(plugin_double).to receive(:instance_identifier).and_return('instance_identifier_foo')
            allow(plugin_double).to receive(:parse_instance_data).and_return({ InstanceId: 'foo' })
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)

            allow(InstanceVerification).to receive(:update_cache).with("127.0.0.1-#{system.login}-#{product.id}", 'foo')
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
              .to_return(status: 201, body: scc_response_body, headers: {})

            expect(InstanceVerification).not_to receive(:update_cache)
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)
            post url, params: payload_token, headers: headers
          end

          it 'returns service JSON' do
            expect(response.body).to eq(serialized_service_json)
          end
        end
      end
    end

    context 'when the system is hybrid' do
      before do
        allow_any_instance_of(InstanceVerification::Providers::Example).to receive(:allowed_extension?).and_return(true)
      end

      context "when system doesn't have hw_info" do
        let(:system) { FactoryBot.create(:system, :hybrid) }

        it 'class instance verification provider' do
          expect(InstanceVerification::Providers::Example).to receive(:new)
              .and_call_original.at_least(:once)
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

        context 'when verification provider raises an exception' do
          before do
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), expected_payload, instance_data).and_return(plugin_double).at_least(:once)
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(nil, nil, nil, instance_data).and_call_original.at_least(:once)
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)
            expect(plugin_double).to receive(:instance_valid?).and_raise('WELL SOMETHING WENT WRONG')
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
              .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), expected_payload, instance_data).and_return(plugin_double).at_least(:once)
            expect(InstanceVerification::Providers::Example).to receive(:new)
              .with(nil, nil, nil, instance_data).and_return(plugin_double).at_least(:once)
            allow(plugin_double).to receive(:instance_identifier).and_return('foo')
            allow(plugin_double).to receive(:allowed_extension?).and_return(true)
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
          token: nil,
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

      let(:scc_response_body) do
        {
          id: 1234567,
          login: 'SCC_3b336b126db1503a9513a14e92a6a62e',
          password: '24f057b7941e80f9cf2d51e16e8af2d6'
        }.to_json
      end

      before do
        allow(InstanceVerification::Providers::Example).to receive(:new)
          .and_return(plugin_double)
        allow(plugin_double).to receive(:instance_identifier).and_return('instance_identifier_foo')
        allow(plugin_double).to receive(:parse_instance_data).and_return({ InstanceId: 'foo' })
        allow(plugin_double).to receive(:allowed_extension?).and_return(true)
        allow(plugin_double).to receive(:add_on).and_return(nil)

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
          .to_return(status: 201, body: scc_response_body, headers: {})

        post url, params: payload, headers: headers
      end

      context 'when the extension is not free' do
        let(:base_product) { FactoryBot.create(:product, :with_mirrored_repositories) }

        context 'when a suitable subscription is found' do
          let(:product) do
            FactoryBot.create(
              :product, :with_mirrored_repositories, :extension, free: false, base_products: [base_product]
              )
          end
          let(:product_classes) { [base_product.product_class, product.product_class] }
          let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

          context 'when no regcode is provided' do
            it 'activates the product' do
              data = JSON.parse(response.body)
              expect(data['product']['free']).to eq(false)
              expect(data['id']).to eq(product.id)
              expect(controller).not_to receive(:update_pubcloud_reg_code)
            end
          end
        end
      end
    end
  end

  describe '#upgrade' do
    subject { response }

    let(:instance_data) { 'dummy_instance_data' }
    let(:request) { put url, headers: headers, params: payload }

    context 'when system is byos' do
      let(:system) do
        FactoryBot.create(
          :system, :byos, :with_system_information,
          pubcloud_reg_code: Base64.strict_encode64('super_token'),
          instance_data: instance_data
        )
      end
      let!(:old_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system) }
      let(:payload) do
        {
          identifier: new_product.identifier,
          version: new_product.version,
          arch: new_product.arch
        }
      end
      let(:scc_systems_products_url) { 'https://scc.suse.com/connect/systems/products' }
      let(:scc_headers) do
        {
          'Accept' => 'application/json,application/vnd.scc.suse.com.v4+json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization' => headers['HTTP_AUTHORIZATION'],
          'Content-Type' => 'application/json',
          'User-Agent' => 'Ruby'
        }
      end
      let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

      context 'when SCC upgrade success' do
        let(:fake_subscription) { instance_double(Subscription, id: 1, products: [new_product]) }

        context "when migration target base product doesn't have an activated successor/predecessor" do
          let(:new_product) { FactoryBot.create(:product, :with_mirrored_repositories) }

          before do
            allow(InstanceVerification::Providers::Example).to receive(:new)
              .and_return(plugin_double)
            allow(plugin_double).to receive(:add_on).and_return('foo')
            stub_request(:put, scc_systems_products_url)
              .with({ headers: scc_headers, body: payload.merge({ byos_mode: 'byos' }) })
              .and_return(status: 201, body: '', headers: {})
            request
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

          before do
            allow(InstanceVerification::Providers::Example).to receive(:new)
              .and_return(plugin_double)
            allow(plugin_double).to receive(:add_on).and_return('foo')
            allow_any_instance_of(described_class).to receive(:find_subscription).and_return(fake_subscription)
            stub_request(:put, scc_systems_products_url)
              .with({ headers: scc_headers, body: payload.merge({ byos_mode: 'byos' }) })
              .and_return(status: 201, body: '', headers: {})
            request
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

      context 'when SCC upgrade fails' do
        before do
          stub_request(:put, scc_systems_products_url)
            .with({ headers: scc_headers, body: payload.merge({ byos_mode: 'byos' }) })
            .and_return(
              status: 401,
              body: 'Migration target not allowed on this instance type',
              headers: {}
            )
        end

        context "when migration target base product doesn't have an activated successor/predecessor" do
          let(:new_product) { FactoryBot.create(:product, :with_mirrored_repositories) }

          before { request }

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
          let(:fake_subscription) { instance_double(Subscription, id: 1, products: [new_product]) }

          before do
            allow_any_instance_of(described_class).to receive(:find_subscription).and_return(fake_subscription)
            request
          end

          it 'HTTP response code is 422' do
            expect(response).to have_http_status(422)
          end

          it 'renders an error' do
            data = JSON.parse(response.body)
            expect(data).to have_key('error')
          end
        end
      end
    end

    context 'when system is payg' do
      let(:system) { FactoryBot.create(:system, :payg, :with_system_information, instance_data: instance_data) }
      let!(:old_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system) }
      let(:payload) do
        {
          identifier: new_product.identifier,
          version: new_product.version,
          arch: new_product.arch
        }
      end

      context "when migration target base product doesn't have an activated successor/predecessor" do
        let(:new_product) { FactoryBot.create(:product, :with_mirrored_repositories) }

        before { request }

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

        before { request }

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
        let(:fake_subscription) { instance_double(Subscription, id: 1, products: [new_product]) }

        before do
          allow_any_instance_of(described_class).to receive(:find_subscription).and_return(fake_subscription)

          request
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
end
# rubocop:enable RSpec/NestedGroups
