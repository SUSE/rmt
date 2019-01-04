require 'rails_helper'

describe Api::Connect::V3::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:product) { FactoryGirl.create(:product, :with_mirrored_repositories, :with_mirrored_extensions) }

  let(:payload) do
    {
      identifier: product.identifier,
      version: product.version,
      arch: product.arch
    }
  end

  describe '#activate' do
    context "when system doesn't have hw_info" do
      let(:system) { FactoryGirl.create(:system) }

      it 'class instance verification provider' do
        expect(InstanceVerification::Providers::Example).to receive(:instance_valid?).with(be_a(ActionDispatch::Request), payload, nil).and_call_original
        post url, params: payload, headers: headers
      end
    end

    context 'when system has hw_info' do
      let(:instance_data) { 'dummy_instance_data' }
      let(:system) { FactoryGirl.create(:system, :with_hw_info, instance_data: instance_data) }
      let(:serialized_service_json) do
        V3::ServiceSerializer.new(
          product.service,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end

      context 'when verification provider returns false' do
        before do
          expect(InstanceVerification::Providers::Example).to receive(:instance_valid?)
            .with(be_a(ActionDispatch::Request), payload, instance_data).and_return(false)
          post url, params: payload, headers: headers
        end

        it 'renders an error' do
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Instance verification failed')
        end
      end

      context 'when verification provider returns true' do
        before do
          expect(InstanceVerification::Providers::Example).to receive(:instance_valid?)
            .with(be_a(ActionDispatch::Request), payload, instance_data).and_return(true)
          post url, params: payload, headers: headers
        end

        it 'renders service JSON' do
          expect(response.body).to eq(serialized_service_json)
        end
      end
    end
  end
end
