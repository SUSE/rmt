require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 4

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:system) { FactoryGirl.create(:system) }

  describe '#destroy' do
    context 'when no credentials are provided' do
      before { delete url }
      subject { response }

      its(:code) { is_expected.to eq('401') }
    end

    context 'when required parameters are missing' do
      it 'raises an error' do
        expect { delete url, headers: headers }.to raise_error ActionController::ParameterMissingTranslated
      end
    end

    context 'when product has no repos' do
      let(:product) { FactoryGirl.create(:product) }
      let(:payload) { { identifier: product.identifier, version: product.version, arch: product.arch } }

      it 'raises an error' do
        expect { delete url, headers: headers, params: payload }.to raise_error(/No repositories found for product/)
      end
    end

    context 'when product is base product has repos' do
      let(:product) { FactoryGirl.create(:product, :with_repositories) }
      let(:payload) { { identifier: product.identifier, version: product.version, arch: product.arch } }

      before { delete url, headers: headers, params: payload }
      subject { response }

      its(:code) { is_expected.to eq('422') }
    end

    context 'when product has repos, is an extension' do
      let(:payload) { { identifier: product.identifier, version: product.version, arch: product.arch } }

      before { delete url, headers: headers, params: payload }
      subject { response }

      context 'and is not activated' do
        let(:product) do
          product = FactoryGirl.create(:product, :with_repositories)
          product.product_type = 'extension'
          product.save!
          product
        end

        its(:code) { is_expected.to eq('422') }
      end

      context 'has products depending on it and is activated' do
        let(:product) do
          activation = FactoryGirl.create(:activation)

          activation.system = system
          activation.save!

          activation.service.product.product_type = 'extension'
          activation.service.product.save!

          ext_activation = FactoryGirl.create(:activation)
          ext_activation.system = system
          ext_activation.save!

          ext_activation.service.product.product_type = 'extension'
          ext_activation.service.product.bases << activation.service.product
          ext_activation.service.product.save!

          activation.service.product
        end

        its(:code) { is_expected.to eq('422') }
      end

      context 'and is activated' do
        let(:product) do
          activation = FactoryGirl.create(:activation)

          activation.system = system
          activation.save!

          activation.service.product.product_type = 'extension'
          activation.service.product.save!
          activation.service.product
        end
        let(:serialized_json) do
          ActiveModelSerializers::SerializableResource.new(
            product.service,
            serializer: ::V3::ServiceSerializer,
            uri_options: { scheme: request.scheme, host: request.host, port: request.port },
            status: status,
            service_url: service_url(product.service)
          ).to_json
        end

        its(:code) { is_expected.to eq('200') }
        its(:body) { is_expected.to eq(serialized_json) }
      end
    end
  end
end
