require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::ProductsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:system) { FactoryBot.create(:system) }
  let(:product) { FactoryBot.create(:product, :with_mirrored_repositories, :with_mirrored_extensions) }

  let(:payload) do
    {
      identifier: product.identifier,
      version: product.version,
      arch: product.arch
    }
  end

  describe '#activate' do
    it_behaves_like 'products controller action' do
      let(:verb) { 'post' }
    end

    it_behaves_like 'product must have mirrored repositories' do
      let(:verb) { 'post' }
    end

    context 'when product has unmet base dependencies' do
      subject { response }

      let(:base_product) { FactoryBot.create(:product, :with_not_mirrored_repositories, :with_mirrored_extensions) }
      let(:product) { base_product.extensions[0] }
      let(:error_json) do
        msg = "The product you are attempting to activate (#{product.friendly_name}) requires one of these products " \
          "to be activated first: #{base_product.friendly_name}"
        { type: 'error', error: msg, localized_error: msg }.to_json
      end

      before { post url, headers: headers, params: payload }
      its(:code) { is_expected.to eq('422') }
      its(:body) { is_expected.to eq(error_json) }
    end

    context 'when product has unmet root dependencies' do
      subject { response }

      let(:system) { FactoryBot.create(:system, :with_activated_base_product) }
      let(:other_root_product) { FactoryBot.create(:product, :with_mirrored_extensions) }
      let(:extension) { FactoryBot.create(:product, :extension, :with_not_mirrored_repositories, base_products: [system.products.first, other_root_product]) }
      let(:product) { FactoryBot.create(:product, :module, :with_mirrored_repositories, base_products: [extension], root_product: other_root_product) }

      let(:error_json) do
        msg = "The product you are attempting to activate (#{product.friendly_name}) is not available on your system's " \
          "base product (#{system.products.first.friendly_name}). #{product.friendly_name} is available on #{other_root_product.friendly_name}."
        { type: 'error', error: msg, localized_error: msg }.to_json
      end

      before do
        create(:activation, system: system, service: extension.service)
        post url, headers: headers, params: payload
      end
      its(:code) { is_expected.to eq('422') }
      its(:body) { is_expected.to eq(error_json) }
    end

    context 'when product has repos' do
      subject { response }

      let(:serialized_json) do
        V3::ServiceSerializer.new(
          product.service,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end

      before { post url, headers: headers, params: payload }
      its(:code) { is_expected.to eq('201') }
      its(:body) { is_expected.to eq(serialized_json) }

      context 'response with "-" in version' do
        let(:product) { FactoryBot.create(:product, :with_mirrored_repositories, :with_mirrored_extensions, version: '24.0') }

        let(:payload) do
          {
            identifier: product.identifier,
            version: '24.0-0',
            arch: product.arch
          }
        end

        its(:code) { is_expected.to eq('201') }
        its(:body) { is_expected.to eq(serialized_json) }
      end

      describe 'JSON response' do
        subject(:json_data) { JSON.parse(response.body, symbolize_names: true) }

        it { is_expected.to include :id, :name, :product, :url, :obsoleted_service_name }
        it 'has extensions' do
          expect(json_data[:product][:extensions]).not_to be_empty
        end
      end
    end

    describe 'activations' do
      subject(:request) { post url, headers: headers, params: payload }

      context 'when the product was already activated on this system' do
        before { Activation.create system: system, service: product.service }

        specify { expect { request }.not_to change { system.activations.reload } }
      end

      context 'when the product was not already activated on this system' do
        specify { expect { request }.to change { system.activations.count }.from(0).to(1) }
      end

      shared_context 'with subscriptions' do
        let(:payload) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch,
            token: regcode
          }
        end

        before { post url, headers: headers, params: payload }
        subject do
          Struct.new(:body, :code).new(
            JSON.parse(response.body, symbolize_names: true),
            response.status
          )
        end
      end

      shared_context 'activate with token in request headers' do
        let(:payload) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch,
            token: regcode
          }
        end

        before { post url, headers: { 'System-Token' => 'existing_token' }.merge(headers), params: payload }
        subject do
          Struct.new(:body, :code, :headers).new(
            JSON.parse(response.body, symbolize_names: true),
            response.status,
            response.headers
          )
        end
      end

      context 'unknown subscription' do
        include_context 'with subscriptions'
        let(:regcode) { 'NOT-EXISTING-SUBSCRIPTION' }

        its(:body) { is_expected.to include(error: /No subscription found with this registration code/) }
        its(:code) { is_expected.to eq(422) }
      end

      context 'subscription does not include product' do
        include_context 'with subscriptions'
        let(:subscription) { create :subscription }
        let(:regcode) { subscription.regcode }

        its(:body) { is_expected.to include(error: /The subscription with the provided Registration Code does not include the requested product/) }
        its(:code) { is_expected.to eq(422) }
      end

      context 'expired subscription' do
        include_context 'with subscriptions'
        let(:subscription) { create :subscription, :expired }
        let(:regcode) { subscription.regcode }

        its(:body) { is_expected.to include(error: /The subscription with the provided Registration Code is expired/) }
        its(:code) { is_expected.to eq(422) }
      end

      context 'subscription with associated product' do
        include_context 'with subscriptions'
        let(:subscription) { create :subscription, :with_products }
        let(:product) { subscription.products.first }
        let(:regcode) { subscription.regcode }

        its(:code) { is_expected.to eq(201) }
        it 'creates activations with subscriptions associated' do
          activation = Activation.find_by(subscription: subscription)
          expect(activation.product).to eq(product)
        end
      end

      context 'token update after activation is success' do
        let(:subscription) { create :subscription, :with_products }
        let(:product) { subscription.products.first }
        let(:regcode) { subscription.regcode }

        include_context 'activate with token in request headers'
        its(:code) { is_expected.to eq(201) }
        its(:headers) { is_expected.to include('System-Token') }
        its(:headers['System-Token']) { is_expected.not_to eq('existing_token') }
      end
    end
  end

  describe '#show' do
    let(:activation) { FactoryBot.create(:activation, :with_mirrored_product) }

    it_behaves_like 'products controller action' do
      let(:verb) { 'get' }
    end

    it_behaves_like 'product must have mirrored repositories' do
      let(:verb) { 'get' }
    end

    context 'when product is not activated' do
      subject { response }

      before { get url, headers: headers, params: payload }
      its(:code) { is_expected.to eq('422') }

      describe 'JSON response' do
        subject { JSON.parse(response.body, symbolize_names: true) }

        its([:error]) { is_expected.to match(/The requested product '.*' is not activated on this system/) }
      end
    end

    context 'when product is activated' do
      let(:system) { activation.system }
      let(:payload) do
        {
          identifier: activation.product.identifier,
          version: activation.product.version,
          arch: activation.product.arch
        }
      end
      let(:serialized_json) do
        V3::ProductSerializer.new(
          activation.service.product,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end

      describe 'response' do
        subject { response }

        before { get url, headers: headers, params: payload }

        its(:code) { is_expected.to eq('200') }
        its(:body) { is_expected.to eq(serialized_json) }
      end

      describe 'response header should contain token' do
        subject { response }

        let(:token_headers) do
          headers.merge({ 'System-Token' => 'some_token' })
        end

        before { get url, headers: token_headers, params: payload }
        its(:code) { is_expected.to eq('200') }
        its(:headers) { is_expected.to include('System-Token') }
      end

      describe 'response with "-" in version' do
        subject { response }

        let(:payload) do
          {
            identifier: activation.product.identifier,
            version: '24.0-0',
            arch: activation.product.arch
          }
        end

        before do
          activation.service.product.update_attribute(:version, '24.0')
          get url, headers: headers, params: payload
        end

        its(:code) { is_expected.to eq('200') }
        its(:body) { is_expected.to eq(serialized_json) }
      end
    end

    context 'when SLE Micro product is activated' do
      let(:system) { FactoryBot.create(:system, :with_activated_product_sle_micro) }
      let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories) }
      let(:payload) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: system.products.first.arch
        }
      end
      let(:serialized_json) do
        V3::ProductSerializer.new(
          product,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end

      describe 'response' do
        subject { response }

        before { get url, headers: headers, params: payload }

        its(:code) { is_expected.to eq('200') }
        its(:body) { is_expected.to eq(serialized_json) }
      end
    end

    context 'with eula_url' do
      subject { response }

      let(:system) { activation.system }
      let(:payload) do
        {
          identifier: activation.product.identifier,
          version: activation.product.version,
          arch: activation.product.arch
        }
      end
      let(:serialized_json) do
        V3::ProductSerializer.new(
          activation.product,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end

      before do
        activation.product.eula_url = 'http://example.com/dummy/eula.txt'
        activation.product.save!

        get url, headers: headers, params: payload
      end
      its(:code) { is_expected.to eq('200') }
      its(:body) { is_expected.to eq(serialized_json) }
      it 'has correct eula_url' do
        product = JSON.parse(serialized_json, symbolize_names: true)
        expect(product[:eula_url]).to eq('http://www.example.com/repo/dummy/eula.txt')

        replacement_url = URI::HTTP.build({ scheme: request.scheme, host: request.host, path: RMT::DEFAULT_MIRROR_URL_PREFIX }).to_s
        expect(product[:eula_url]).to eq(
          RMT::Misc.replace_uri_parts(activation.product.eula_url, replacement_url)
        )
      end
    end
  end

  describe '#upgrade' do
    subject { response }

    let(:request) { put url, headers: headers, params: payload }
    let(:new_product) { FactoryBot.create(:product, :with_mirrored_repositories) }
    let(:payload) do
      {
        identifier: new_product.identifier,
        version: new_product.version,
        arch: new_product.arch
      }
    end
    let(:serialized_json) do
      V3::ServiceSerializer.new(
        new_product.service,
        base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
      ).to_json
    end

    it_behaves_like 'products controller action' do
      let(:verb) { 'put' }
    end

    before do
      request
      system.reload
    end

    it 'calls refresh_system_token after upgrade action when system token header is present' do
      put url, headers: headers.merge('System-Token' => 'test_token'), params: payload
      expect(response.code).to eq('201')
      expect(response.headers).to include('System-Token')
      expect(response.headers['System-Token']).not_to eq('test_token')
    end

    it 'No update in token after upgrade action when system token header is absent' do
      put url, headers: headers, params: payload
      expect(response.code).to eq('201')
      expect(response.headers).not_to include('System-Token')
    end
    context 'new product' do
      its(:code) { is_expected.to eq('201') }
      its(:body) { is_expected.to eq(serialized_json) }

      it('has one activation') { expect(system.activations.count).to eq(1) }

      it 'activates new product' do
        expect(system.activations.first.reload.service_id).to equal(new_product.service.id)
      end
    end

    context 'with activated previous product' do
      let!(:old_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system) }
      let(:new_product) { FactoryBot.create(:product, :with_mirrored_repositories, predecessors: [old_product]) }
      let(:serialized_json) do
        V3::ServiceSerializer.new(
          new_product.service,
          obsoleted_service_name: old_product.service.name,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end


      its(:code) { is_expected.to eq('201') }
      its(:body) { is_expected.to eq(serialized_json) }

      it('has one activation') { expect(system.activations.count).to eq(1) }

      it 'deactivates old product and activates new product' do
        expect(system.activations.first.reload.service_id).to equal(new_product.service.id)
      end
    end

    context 'with "-" in product version' do
      let(:new_product) { FactoryBot.create(:product, :with_mirrored_repositories, version: '24.0') }
      let(:payload) do
        {
          identifier: new_product.identifier,
          version: '24.0-0',
          arch: new_product.arch
        }
      end

      its(:code) { is_expected.to eq('201') }
      its(:body) { is_expected.to eq(serialized_json) }
    end

    context 'with paid activated previous product' do
      let(:subscription) { create :subscription }
      let!(:old_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system, subscription: subscription) }
      let(:new_product) { FactoryBot.create(:product, :with_mirrored_repositories, predecessors: [old_product]) }
      let(:serialized_json) do
        V3::ServiceSerializer.new(
          new_product.service,
          obsoleted_service_name: old_product.service.name,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end


      its(:code) { is_expected.to eq('201') }
      its(:body) { is_expected.to eq(serialized_json) }

      it('has one activation') { expect(system.activations.count).to eq(1) }
      it 'moves subscription to new_product' do
        expect(system.activations.reload.first.subscription).to eq(subscription)
      end

      it 'deactivates old product and activates new product' do
        expect(system.activations.first.reload.service_id).to equal(new_product.service.id)
      end
    end
  end

  describe 'online/offline migrations' do
    shared_examples 'migration return values' do
      before { post url, headers: headers, params: payload }

      subject { response }

      context 'without installed_products' do
        let(:payload) { {} }
        let(:error_response) do
          {
            type: 'error',
            error: "Required parameters are missing or empty: #{required_params}",
            localized_error: "Required parameters are missing or empty: #{required_params}"
          }.to_json
        end

        its(:code) { is_expected.to eq('422') }
        its(:body) { is_expected.to eq(error_response) }
      end

      context 'with no base product in installed_products' do
        let(:payload) do
          {
            'installed_products': [ { 'identifier': 'non_existent_product', 'version': '42', 'arch': 'x86_64', 'release_type': nil } ],
            'target_base_product': { 'identifier': 'SLES', 'version': '15', 'arch': 'x86_64' }
          }
        end
        let(:error_response) do
          { type: 'error', error: 'No base product found.', localized_error: 'No base product found.' }.to_json
        end

        its(:code) { is_expected.to eq('422') }
        its(:body) { is_expected.to eq(error_response) }
      end

      context 'with not activated product in installed_products' do
        let(:product) { FactoryBot.create(:product, :with_mirrored_repositories, product_type: 'base') }
        let(:payload) do
          {
            'installed_products': [
              { 'identifier': product.identifier, 'version': product.version, 'arch': product.arch, 'release_type': product.release_type }
            ],
            'target_base_product': {
              'identifier': 'SLES', 'version': '15', 'arch': 'x86_64'
            }
          }
        end
        let(:error_response) do
          {
            type: 'error',
            error: "The requested products '#{product.friendly_name}' are not activated on the system.",
            localized_error: "The requested products '#{product.friendly_name}' are not activated on the system."
          }.to_json
        end

        its(:code) { is_expected.to eq('422') }
        its(:body) { is_expected.to eq(error_response) }
      end

      context 'with multiple base products in installed_products' do
        let(:first_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
        let(:second_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
        let(:payload) do
          {
            'installed_products': [
              {
                'identifier': first_product.identifier,
                'version': first_product.version,
                'arch': first_product.arch,
                'release_type': first_product.release_type
              },
              {
                'identifier': second_product.identifier,
                'version': second_product.version,
                'arch': second_product.arch,
                'release_type': second_product.release_type
              }
            ],
            'target_base_product': { 'identifier': 'SLES', 'version': '15', 'arch': 'x86_64' }
          }
        end
        let(:error_response) do
          {
            type: 'error',
            error: "Multiple base products found: '#{first_product.friendly_name}, #{second_product.friendly_name}'.",
            localized_error: "Multiple base products found: '#{first_product.friendly_name}, #{second_product.friendly_name}'."
          }.to_json
        end

        its(:code) { is_expected.to eq('422') }
        its(:body) { is_expected.to eq(error_response) }
      end

      context 'with a proper set of products in installed_products' do
        let(:first_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
        let(:second_product) do
          FactoryBot.create(
            :product,
            :with_mirrored_repositories,
            product_type: 'base',
            predecessors: [first_product],
            migration_kind: migration_kind
          )
        end
        let(:payload) do
          product = second_product.predecessors.first # For initializing everything in the correct order
          {
            'installed_products': [ {
              'identifier': product.identifier,
              'version': product.version,
              'arch': product.arch,
              'release_type': product.release_type
            } ],
            'target_base_product': {
              'identifier': second_product.identifier,
              'version': second_product.version,
              'arch': second_product.arch,
              'release_type': second_product.release_type
            }
          }
        end
        let(:expected_response) do
          [[::V3::UpgradePathItemSerializer.new(second_product)]].to_json
        end

        its(:code) { is_expected.to eq('200') }
        its(:body) do
          is_expected.to eq(expected_response)
        end

        context 'with recommended module' do
          subject do
            post url, headers: headers, params: payload
            response
          end

          let!(:recommended_module) do
            recommended_module = create(:product, :module, :with_mirrored_repositories, base_products: [second_product])

            ProductsExtensionsAssociation.find_by(
              product: second_product,
              extension: recommended_module,
              root_product: second_product
            ).update!(recommended: true)
            recommended_module
          end
          let!(:expected_response) do
            case migration_kind
            when :online
              [[::V3::UpgradePathItemSerializer.new(second_product)]].to_json
            when :offline
              [[::V3::UpgradePathItemSerializer.new(second_product), ::V3::UpgradePathItemSerializer.new(recommended_module)]].to_json
            end
          end

          its(:code) { is_expected.to eq('200') }
          its(:body) do
            is_expected.to eq(expected_response)
          end
        end

        context 'with migration_extra module' do
          subject do
            post url, headers: headers, params: payload
            response
          end

          let!(:migration_extra_module) do
            migration_extra_module = create(:product, :module, :with_mirrored_repositories, base_products: [second_product])

            ProductsExtensionsAssociation.find_by(
              product: second_product,
              extension: migration_extra_module,
              root_product: second_product
            ).update!(migration_extra: true)
            migration_extra_module
          end
          let!(:expected_response) do
            case migration_kind
            when :online
              [[::V3::UpgradePathItemSerializer.new(second_product)]].to_json
            when :offline
              [[::V3::UpgradePathItemSerializer.new(second_product), ::V3::UpgradePathItemSerializer.new(migration_extra_module)]].to_json
            end
          end

          its(:code) { is_expected.to eq('200') }
          its(:body) do
            is_expected.to eq(expected_response)
          end
        end

        context 'when not all extensions are upgradeable' do
          let(:first_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
          let(:module_without_successor) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'module') }
          let(:second_product) do
            FactoryBot.create(
              :product,
              :with_mirrored_repositories,
              product_type: 'base',
              predecessors: [first_product],
              migration_kind: migration_kind
            )
          end
          let(:payload) do
            product = second_product.predecessors.first # For initializing everything in the correct order
            {
              'installed_products': [ {
                'identifier': product.identifier,
                'version': product.version,
                'arch': product.arch,
                'release_type': product.release_type
              },
                                      {
                                        'identifier': module_without_successor.identifier,
                                        'version': module_without_successor.version,
                                        'arch': module_without_successor.arch,
                                        'release_type': module_without_successor.release_type
                                      } ],
              'target_base_product': {
                'identifier': second_product.identifier,
                'version': second_product.version,
                'arch': second_product.arch,
                'release_type': second_product.release_type
              }
            }
          end

          its(:code) { is_expected.to eq('422') }
          its(:body) do
            is_expected.to match(/The product\(s\) are '#{module_without_successor.friendly_name}'/)
          end
        end
      end

      context 'with "-0" version suffix' do
        let(:first_product) { FactoryBot.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
        let(:second_product) do
          FactoryBot.create(
            :product,
            :with_mirrored_repositories,
            product_type: 'base',
            predecessors: [first_product],
            migration_kind: migration_kind
          )
        end
        let(:payload) do
          product = second_product.predecessors.first # For initializing everything in the correct order
          {
            'installed_products': [ {
              'identifier': product.identifier,
              'version': product.version + '-0',
              'arch': product.arch,
              'release_type': product.release_type
            } ],
            'target_base_product': {
              'identifier': second_product.identifier,
              'version': second_product.version + '-0',
              'arch': second_product.arch,
              'release_type': second_product.release_type
            }
          }
        end
        let(:expected_response) do
          [[::V3::UpgradePathItemSerializer.new(second_product)]].to_json
        end

        its(:code) { is_expected.to eq('200') }
        its(:body) do
          is_expected.to eq(expected_response)
        end
      end
    end

    describe '#migrations' do
      let(:url) { connect_systems_products_migrations_url }
      let(:required_params) { 'installed_products' }
      let(:migration_kind) { :online }

      include_examples 'migration return values'
    end

    describe '#offline_migrations' do
      let(:url) { connect_systems_products_offline_migrations_url }
      let(:required_params) { 'installed_products, target_base_product' }
      let(:migration_kind) { :offline }

      include_examples 'migration return values'
    end
  end
end
