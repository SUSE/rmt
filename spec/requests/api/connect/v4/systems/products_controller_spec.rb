require 'rails_helper'

RSpec.describe Api::Connect::V4::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 4

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:system) { FactoryBot.create(:system, :with_activated_base_product) }

  describe '#destroy' do
    subject { response }

    let(:product) { FactoryBot.create(:product, :with_mirrored_repositories) }
    let(:payload) { { identifier: product.identifier, version: product.version, arch: product.arch } }

    before { delete url, headers: headers, params: payload }

    it_behaves_like 'products controller action' do
      let(:product) { FactoryBot.create(:product, :with_mirrored_repositories) }
      let(:verb) { 'delete' }
    end

    context 'when the product is a base product' do
      its(:code) { is_expected.to eq('422') }

      describe 'JSON response' do
        subject { JSON.parse(response.body, symbolize_names: true) }

        its([:error]) { is_expected.to match(/The product ".*?" is a base product and cannot be deactivated/) }
      end
    end

    context 'when the product is an unactivated extension' do
      let(:product) { FactoryBot.create(:product, :extension, :with_mirrored_repositories) }

      its(:code) { is_expected.to eq('422') }

      describe 'JSON response' do
        subject { JSON.parse(response.body, symbolize_names: true) }

        its([:error]) { is_expected.to match(/is not yet activated on the system./) }
      end
    end

    context 'when the product is an activated extension' do
      let(:system) { FactoryBot.create(:system) }
      let(:product) { FactoryBot.create(:product, :extension, :with_mirrored_repositories, :activated, system: system) }
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

    context 'when the product is an activated extension with no dependencies' do
      let(:product) do
        product = FactoryBot.create(:product, :extension, :with_mirrored_repositories, :activated, system: system)
        FactoryBot.create(:product, :extension, :with_mirrored_repositories, :activated, system: system, base_products: [product])
        product
      end

      its(:code) { is_expected.to eq('422') }

      describe 'JSON response' do
        subject { JSON.parse(response.body, symbolize_names: true) }

        its([:error]) { is_expected.to match(/Cannot deactivate the product ".*"\. Other activated products depend upon it/) }
      end
    end
  end

  describe '#synchronize' do
    let!(:additional_activation) { FactoryBot.create(:activation, system: system) }
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
