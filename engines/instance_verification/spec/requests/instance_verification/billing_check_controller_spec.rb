require 'rails_helper'

module InstanceVerification
  RSpec.describe BillingCheckController, type: :request do
    describe '#byos and payg check' do
      let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

      context 'when system is SLES and PAYG and valid billing code' do
        let(:billing_info) do
          {
            billing_product: '1234_SUSE_SLES',
            marketplace_code: nil
          }
        end

        it 'returns PAYG' do
          get '/api/instance/check', params: { metadata: billing_info.to_s, identifier: 'SLES' }
          expect(JSON.parse(response.body)['flavor']).to eq('PAYG')
        end
      end

      context 'when system is SLES4SAP and PAYG and valid billing code' do
        let(:billing_info) do
          {
            billing_product: nil,
            marketplace_code: ['6789_SUSE_SAP']
          }
        end

        it 'returns PAYG' do
          get '/api/instance/check', params: { metadata: billing_info.to_s, identifier: 'SLES_SAP' }
          expect(JSON.parse(response.body)['flavor']).to eq('PAYG')
        end
      end

      context 'when no valid billing code' do
        let(:billing_info) do
          {
            billing_product: ['foo'],
            marketplace_code: ['bar']
          }
        end

        it 'returns BYOS' do
          get '/api/instance/check', params: { metadata: billing_info.to_s, identifier: 'SLES' }
          expect(JSON.parse(response.body)['flavor']).to eq('BYOS')
        end
      end
    end
  end
end
