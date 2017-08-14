require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::ProductsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:system) { FactoryGirl.create(:system) }
  let(:product_with_repos) { FactoryGirl.create(:product, :with_mirrored_repositories) }

  describe '#activate' do
    it_behaves_like 'products controller action' do
      let(:verb) { 'post' }
    end

    context 'when product mandatory repos aren\'t mirrored' do
    end

    context 'when product has repos' do
      subject { response }

      let(:payload) do
        {
          identifier: product_with_repos.identifier,
          version: product_with_repos.version,
          arch: product_with_repos.arch
        }
      end
      let(:serialized_json) do
        V3::ServiceSerializer.new(
          product_with_repos.service,
          base_url: 'http://www.example.com',
          status: status
        ).to_json
      end

      before { post url, headers: headers, params: payload }
      its(:code) { is_expected.to eq('201') }
      its(:body) { is_expected.to eq(serialized_json) }

      describe 'JSON response' do
        subject { JSON.parse(response.body, symbolize_names: true) }

        it { is_expected.to include :id, :name, :product, :url, :obsoleted_service_name }
      end
    end
  end

  describe '#show' do
    let(:activation) { FactoryGirl.create(:activation, :with_mirrored_product) }

    it_behaves_like 'products controller action' do
      let(:verb) { 'get' }
    end

    context 'when product is not activated' do
      subject { response }

      let(:payload) do
        {
          identifier: product_with_repos.identifier,
          version: product_with_repos.version,
          arch: product_with_repos.arch
        }
      end

      before { get url, headers: headers, params: payload }
      its(:code) { is_expected.to eq('422') }

      describe 'JSON response' do
        subject { JSON.parse(response.body, symbolize_names: true) }

        its([:error]) { is_expected.to match(/The requested product '.*' is not activated on this system/) }
      end
    end

    context 'when product is activated' do
      subject { response }

      let(:system) { activation.system }
      let(:payload) do
        {
          identifier: activation.service.product.identifier,
          version: activation.service.product.version,
          arch: activation.service.product.arch
        }
      end
      let(:serialized_json) do
        V3::ProductSerializer.new(
          activation.service.product,
          base_url: 'http://www.example.com'
        ).to_json
      end

      before { get url, headers: headers, params: payload }
      its(:code) { is_expected.to eq('200') }
      its(:body) { is_expected.to eq(serialized_json) }
    end
  end
end
