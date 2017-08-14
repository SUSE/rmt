require 'rails_helper'

RSpec.describe Api::Connect::V4::Systems::ProductsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 4

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:system) { FactoryGirl.create(:system) }

  describe '#destroy' do
    it_behaves_like 'products controller action' do
      let(:product_with_repos) { FactoryGirl.create(:product, :with_mirrored_repositories) }
      let(:verb) { 'delete' }
    end

    context 'when product is base product has repos' do
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

    context 'when product has repos, is an extension' do
      subject { response }

      let(:payload) { { identifier: product.identifier, version: product.version, arch: product.arch } }

      before { delete url, headers: headers, params: payload }
      context 'and is not activated' do
        let(:product) { FactoryGirl.create(:product, :extension, :with_mirrored_repositories) }

        its(:code) { is_expected.to eq('422') }

        describe 'JSON response' do
          subject { JSON.parse(response.body, symbolize_names: true) }

          its([:error]) { is_expected.to match(/is not yet activated on the system./) }
        end
      end

      context 'has products depending on it and is activated' do
        let(:product) do
          product = FactoryGirl.create(:product, :extension, :with_mirrored_repositories, :activated, system: system)
          ext_product = FactoryGirl.create(:product, :extension, :with_mirrored_repositories, :activated, system: system)
          ext_product.bases << product
          ext_product.save!

          product
        end

        its(:code) { is_expected.to eq('422') }

        describe 'JSON response' do
          subject { JSON.parse(response.body, symbolize_names: true) }

          its([:error]) { is_expected.to match(/Cannot deactivate the product ".*"\. Other activated products depend upon it/) }
        end
      end

      context 'and is activated' do
        let(:system) { FactoryGirl.create(:system) }
        let(:product) { FactoryGirl.create(:product, :extension, :with_mirrored_repositories, :activated, system: system) }
        let(:serialized_json) do
          V3::ServiceSerializer.new(
            product.service,
            base_url: 'http://www.example.com',
            status: status
          ).to_json
        end

        its(:code) { is_expected.to eq('200') }
        its(:body) { is_expected.to eq(serialized_json) }
      end
    end
  end
end
