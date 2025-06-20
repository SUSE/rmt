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

      context 'when metadata can not be parsed' do
        let(:billing_info) do
          {
            billing_product: ['foo'],
            marketplace_code: ['bar']
          }
        end
        let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

        it 'returns BYOS' do
          expect(InstanceVerification::Providers::Example).to receive(:new).at_least(:once).and_return(plugin_double)
          allow(plugin_double).to receive(:parse_instance_data).and_raise(InstanceVerification::Exception, 'Malformed instance data')
          get '/api/instance/check', params: { metadata: billing_info.to_s, identifier: 'SLES' }
          expect(JSON.parse(response.body)['flavor']).to eq('BYOS')
          expect(response.message).to eq('Unprocessable Entity')
          expect(response.code).to eq("422")
        end
      end
    end
  end
end
