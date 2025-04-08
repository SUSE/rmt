require 'rails_helper'

describe Api::Connect::V3::Systems::ActivationsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activations' do
    let(:system) { FactoryBot.create(:system, :with_activated_product) }
    let(:headers) { auth_header.merge(version_header) }

    before do
      allow_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(true)
      allow(InstanceVerification).to receive(:reg_code_in_cache?).and_return(nil)
      allow(InstanceVerification).to receive(:update_cache)
      get '/connect/systems/activations', headers: headers
    end

    context 'without X-Instance-Data headers or hw_info' do
      it 'has service URLs with HTTP scheme' do
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
        expect_any_instance_of(InstanceVerification::Providers::Example).not_to receive(:instance_valid?)
        expect(InstanceVerification).not_to receive(:update_cache)
      end
    end

    context 'with instance_data in hw_info' do
      let(:system) { FactoryBot.create(:system, :with_activated_product, :with_system_information, instance_data: '<repoformat>plugin:susecloud</repoformat>') }

      it 'has service URLs with HTTP scheme' do
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
        expect_any_instance_of(InstanceVerification::Providers::Example).not_to receive(:instance_valid?)
        expect(InstanceVerification).not_to receive(:update_cache)
      end
    end

    context 'with X-Instance-Data headers' do
      let(:headers) { auth_header.merge(version_header).merge({ 'X-Instance-Data' => 'instance_data' }) }

      it 'has service URLs with HTTP scheme' do
        allow(File).to receive(:exist?).and_return(true)
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
      end
    end
  end
end
