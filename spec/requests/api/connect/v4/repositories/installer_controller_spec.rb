require 'rails_helper'

RSpec.describe Api::Connect::V4::Repositories::InstallerController do
  include_context 'version header', 4

  let(:url) { connect_default_repositories_installer_url }

  describe '#show' do
    subject { response }

    context 'without product' do
      before { get url }

      let(:error_response) do
        {
          type: 'error',
          error: 'Required parameters are missing or empty: identifier, version, arch',
          localized_error: 'Required parameters are missing or empty: identifier, version, arch'
        }
      end

      its(:body) { is_expected.to eq error_response.to_json }
      its(:code) { is_expected.to eq('422') }
    end

    context 'with unknown product' do
      let(:params) { { identifier: 'dummy_product', version: '42', arch: 'x86_64' } }
      let(:error_response) do
        {
          type: 'error',
          error: 'No product found on RMT for: dummy_product 42 x86_64',
          localized_error: 'No product found on RMT for: dummy_product 42 x86_64'
        }
      end

      before { get url, params: params }

      its(:body) { is_expected.to eq error_response.to_json }
      its(:code) { is_expected.to eq('422') }
    end

    context 'with known product with not mirrored repositories' do
      let(:product) { FactoryGirl.create(:product, :with_not_mirrored_repositories) }
      let(:params) { { identifier: product.identifier, version: product.version, arch: product.arch } }

      before { get url, params: params }

      its(:body) { is_expected.to eq '[]' }
      its(:code) { is_expected.to eq('200') }
    end

    context 'with known product and empty string as release_type' do
      let(:product) { FactoryGirl.create(:product, :with_not_mirrored_repositories) }
      let(:params) { { identifier: product.identifier, version: product.version, arch: product.arch, release_type: '' } }

      before { get url, params: params }

      its(:body) { is_expected.to eq '[]' }
      its(:code) { is_expected.to eq('200') }
    end

    describe 'response with "-" in product version' do
      let(:product) { FactoryGirl.create(:product, :with_not_mirrored_repositories, version: '24.0') }
      let(:params) { { identifier: product.identifier, version: '24.0-0', arch: product.arch } }

      before { get url, params: params }

      its(:body) { is_expected.to eq '[]' }
      its(:code) { is_expected.to eq('200') }
    end

    context 'with known product with mirrored installer update repositories' do
      let(:product) { FactoryGirl.create(:product, :with_mirrored_repositories) }
      let(:params) { { identifier: product.identifier, version: product.version, arch: product.arch } }
      let(:serialized_response) do
        ActiveModel::Serializer::CollectionSerializer.new(
          product.repositories.where(installer_updates: true),
          serializer: ::V3::RepositorySerializer,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host })
        ).to_json
      end

      before { get url, params: params }

      its(:body) { is_expected.to eq serialized_response }
      its(:code) { is_expected.to eq('200') }
    end
  end
end
