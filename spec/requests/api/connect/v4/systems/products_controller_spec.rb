require 'rails_helper'

RSpec.describe Api::Connect::V4::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 4

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:system) { FactoryGirl.create(:system, :with_activated_base_product) }

  describe '#destroy' do
    it_behaves_like 'products controller action' do
      let(:product) { FactoryGirl.create(:product, :with_mirrored_repositories) }
      let(:verb) { 'delete' }
    end

    context 'when the product is a base product' do
      subject { response }

      let(:product) { FactoryGirl.create(:product, :with_mirrored_repositories) }
      let(:payload) { { identifier: product.identifier, version: product.version, arch: product.arch } }

      before { delete url, headers: headers, params: payload }
      its(:code) { is_expected.to eq('422') }

      describe 'JSON response' do
        subject { JSON.parse(response.body, symbolize_names: true) }

        its([:error]) { is_expected.to match(/The product ".*?" is a base product and cannot be deactivated/) }
      end
    end

    context 'when the product is an extension' do
      subject { response }

      let(:payload) { { identifier: product.identifier, version: product.version, arch: product.arch } }

      before { delete url, headers: headers, params: payload }

      context 'and it is not activated' do
        let(:product) { FactoryGirl.create(:product, :extension, :with_mirrored_repositories) }

        its(:code) { is_expected.to eq('422') }

        describe 'JSON response' do
          subject { JSON.parse(response.body, symbolize_names: true) }

          its([:error]) { is_expected.to match(/is not yet activated on the system./) }
        end
      end

      context 'and the system has other extensions that depend on this one' do
        let(:product) do
          product = FactoryGirl.create(:product, :extension, :with_mirrored_repositories, :activated, system: system)
          FactoryGirl.create(:product, :extension, :with_mirrored_repositories, :activated, system: system, base_products: [product])
          product
        end

        its(:code) { is_expected.to eq('422') }

        describe 'JSON response' do
          subject { JSON.parse(response.body, symbolize_names: true) }

          its([:error]) { is_expected.to match(/Cannot deactivate the product ".*"\. Other activated products depend upon it/) }
        end
      end

      context 'and it is activated' do
        let(:system) { FactoryGirl.create(:system) }
        let(:product) { FactoryGirl.create(:product, :extension, :with_mirrored_repositories, :activated, system: system) }
        let(:serialized_json) do
          V3::ServiceSerializer.new(
            product.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s,
            status: status
          ).to_json
        end

        its(:code) { is_expected.to eq('200') }
        its(:body) { is_expected.to eq(serialized_json) }
      end
    end
  end

  describe '#synchronize' do
    let!(:additional_activation) { FactoryGirl.create(:activation, system: system) }
    let(:path) { '/connect/systems/products/synchronize' }

    # context 'without products param' do
    #   before { post path, headers: headers }
    #   subject { response }
    #
    #   its(:status) { is_expected.to eq 400 }
    # end

    context 'In sync' do
      it 'checks the system activations and returns a list of system products' do
        params = system.products.map do |product|
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch,
            release_type: product.release_type
          }
        end

        post path, params: { products: params }, headers: headers

        expect(response.status).to eq 200
        expect(json_response.map { |p| p[:id] }).to match_array(system.product_ids)
      end
    end

    context 'In sync with "-0" version suffix' do
      it 'checks the system activations and returns a list of system products' do
        params = system.products.map do |product|
          {
            identifier: product.identifier,
            version: product.version + '-0',
            arch: product.arch,
            release_type: product.release_type
          }
        end

        post path, params: { products: params }, headers: headers

        expect(response.status).to eq 200
        expect(json_response.map { |p| p[:id] }).to match_array(system.product_ids)
      end
    end

    context 'Out of sync' do
      it 'removes obsolete activations' do
        product = system.products.first
        params = {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch,
          release_type: product.release_type
        }

        post path, params: { products: [params] }, headers: headers

        expect(response.status).to eq 200
        expect(json_response.map { |p| p[:id] }).to match_array([product.id])
        expect(system.activations.reload).not_to include(additional_activation)
      end
    end
  end
end
