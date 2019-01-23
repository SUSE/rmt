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
    let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

    context "when system doesn't have hw_info" do
      let(:system) { FactoryGirl.create(:system) }

      it 'class instance verification provider' do
        expect(InstanceVerification::Providers::Example).to receive(:new)
          .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, nil).and_call_original
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
          expect(InstanceVerification::Providers::Example).to receive(:new)
            .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
          expect(plugin_double).to receive(:instance_valid?).and_return(false)
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
            .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
          expect(plugin_double).to receive(:instance_valid?).and_raise('Custom plugin error')
          post url, params: payload, headers: headers
        end

        it 'renders an error with exception details' do
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Unexpected instance verification error has occurred')
        end
      end

      context 'when verification provider raises an unhandled exception' do
        before do
          expect(InstanceVerification::Providers::Example).to receive(:new)
            .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_return(plugin_double)
          expect(plugin_double).to receive(:instance_valid?).and_raise(InstanceVerification::Exception, 'Custom plugin error')
          post url, params: payload, headers: headers
        end

        it 'renders an error with exception details' do
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Instance verification failed: Custom plugin error')
        end
      end

      context 'when verification provider returns true' do
        before do
          expect(InstanceVerification::Providers::Example).to receive(:new)
            .with(be_a(ActiveSupport::Logger), be_a(ActionDispatch::Request), payload, instance_data).and_call_original
          post url, params: payload, headers: headers
        end

        it 'renders service JSON' do
          expect(response.body).to eq(serialized_service_json)
        end
      end
    end
  end

  describe '#upgrade' do
    subject { response }

    let(:system) { FactoryGirl.create(:system) }
    let(:request) { put url, headers: headers, params: payload }
    let!(:old_product) { FactoryGirl.create(:product, :with_mirrored_repositories, :activated, system: system) }
    let(:payload) do
      {
        identifier: new_product.identifier,
        version: new_product.version,
        arch: new_product.arch
      }
    end

    before { request }

    context "when migration target base product doesn't have an activated successor/predecessor" do
      let(:new_product) { FactoryGirl.create(:product, :with_mirrored_repositories) }

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
        FactoryGirl.create(
          :product, :with_mirrored_repositories,
          identifier: old_product.identifier + '-foo', predecessors: [ old_product ]
        )
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
        FactoryGirl.create(
          :product, :with_mirrored_repositories, identifier: old_product.identifier,
          version: '999', predecessors: [ old_product ]
        )
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
