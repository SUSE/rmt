require 'rails_helper'

describe Api::Connect::V3::Systems::ActivationsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activations' do
    let(:system) { FactoryGirl.create(:system, :with_activated_product) }
    let(:headers) { auth_header.merge(version_header) }

    before { get '/connect/systems/activations', headers: headers }

    context 'without X-Instance-Data headers or hw_info' do
      it 'has service URLs with HTTP scheme' do
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
      end
    end

    context 'with instance_data in hw_info' do
      let(:system) { FactoryGirl.create(:system, :with_activated_product, :with_hw_info, instance_data: '<repoformat>plugin:susecloud</repoformat>') }

      it 'has service URLs with HTTP scheme' do
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
      end
    end

    context 'with X-Instance-Data headers' do
      let(:headers) { auth_header.merge(version_header).merge({ 'X-Instance-Data' => 'instance_data' }) }

      it 'has service URLs with HTTP scheme' do
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
      end
    end
  end
end
