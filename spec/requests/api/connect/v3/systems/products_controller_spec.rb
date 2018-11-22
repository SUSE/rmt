require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::ProductsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:system) { FactoryGirl.create(:system) }
  let(:product) { FactoryGirl.create(:product, :with_mirrored_repositories, :with_mirrored_extensions) }

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

    context 'when product has unmet dependencies' do
      subject { response }

      let(:base_product) { FactoryGirl.create(:product, :with_not_mirrored_repositories, :with_mirrored_extensions) }
      let(:product) { base_product.extensions[0] }
      let(:error_json) do
        {
          type: 'error',
          error: "Unmet product dependencies, activate one of these products first: #{base_product.friendly_name}",
          localized_error: "Unmet product dependencies, activate one of these products first: #{base_product.friendly_name}"
        }.to_json
      end

      before { post url, headers: headers, params: payload }
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
        let(:product) { FactoryGirl.create(:product, :with_mirrored_repositories, :with_mirrored_extensions, version: '24.0') }

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
    end
  end

  describe '#show' do
    let(:activation) { FactoryGirl.create(:activation, :with_mirrored_product) }

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
    let(:new_product) { FactoryGirl.create(:product, :with_mirrored_repositories) }
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

    context 'new product' do
      its(:code) { is_expected.to eq('201') }
      its(:body) { is_expected.to eq(serialized_json) }

      it('has one activation') { expect(system.activations.count).to eq(1) }

      it 'activates new product' do
        expect(system.activations.first.reload.service_id).to equal(new_product.service.id)
      end
    end

    context 'with activated previous product' do
      let!(:old_product) { FactoryGirl.create(:product, :with_mirrored_repositories, :activated, system: system) }
      let(:new_product) { FactoryGirl.create(:product, :with_mirrored_repositories, predecessors: [old_product]) }
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
      let(:new_product) { FactoryGirl.create(:product, :with_mirrored_repositories, version: '24.0') }
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
        let(:product) { FactoryGirl.create(:product, :with_mirrored_repositories, product_type: 'base') }
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
        let(:first_product) { FactoryGirl.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
        let(:second_product) { FactoryGirl.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
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
        let(:first_product) { FactoryGirl.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
        let(:second_product) do
          FactoryGirl.create(
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
      end

      context 'with "-0" version suffix' do
        let(:first_product) { FactoryGirl.create(:product, :with_mirrored_repositories, :activated, system: system, product_type: 'base') }
        let(:second_product) do
          FactoryGirl.create(
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
