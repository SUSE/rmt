require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
describe StrictAuthentication::AuthenticationController, type: :request do
  subject { response }

  let(:system) { FactoryBot.create(:system, :with_activated_product) }

  describe '#check' do
    context 'with valid credentials' do
      include_context 'auth header', :system, :login, :password

      let(:requested_uri) { '/repo' + system.repositories.first[:local_path] + '/repodata/repomd.xml' }

      context 'without instance_data headers' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri }) }

        before do
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(false)
          get '/api/auth/check', headers: headers
        end

        it { is_expected.to have_http_status(403) }
      end

      context 'with instance_data headers and instance data is invalid' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': 'test' }) }

        before do
          Rails.cache.clear
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(false)
          get '/api/auth/check', headers: headers
        end

        it do
          is_expected.to have_http_status(403)
        end
      end

      context 'when system is BYOS proxy' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': 'test' }) }
        let(:body_active) do
          {
            id: 1,
            regcode: '631dc51f',
            name: 'Subscription 1',
            type: 'FULL',
            status: 'ACTIVE',
            starts_at: 'null',
            expires_at: '2014-03-14T13:10:21.164Z',
            system_limit: 6,
            systems_count: 1,
            product_classes: [
              'SLES'
            ],
            families: [
              'sles',
              'sled'
            ],
            skus: [
              'sku1',
              'sku2'
            ],
            systems: [
              {
                id: 14,
                login: 'SCC_FOO',
                password: 'secret',
                last_seen_at: '2010-03-14T13:10:21.164Z'
              }
            ],
            product_ids: [
              239
            ]
          }
        end
        let(:body_expired) do
          {
            id: 1,
            regcode: '631dc51f',
            name: 'Subscription 1',
            type: 'FULL',
            status: 'EXPIRED',
            starts_at: 'null',
            expires_at: '2014-03-14T13:10:21.164Z',
            system_limit: 6,
            systems_count: 1,
            product_classes: [
              'SLES'
            ],
            families: [
              'sles',
              'sled'
            ],
            skus: [
              'sku1',
              'sku2'
            ],
            systems: [
              {
                id: 14,
                login: 'SCC_FOO',
                password: 'secret',
                last_seen_at: '2010-03-14T13:10:21.164Z'
              }
            ],
            product_ids: [
              239
            ]
          }
        end
        let(:requested_uri) { '/repo' + system_byos.repositories.first[:local_path] + '/repodata/repomd.xml' }
        let(:system_byos) { FactoryBot.create(:system, :byos, :with_activated_product) }
        let(:scc_systems_subscriptions_url) { 'https://scc.suse.com/connect/systems/subscriptions' }

        include_context 'auth header', :system_byos, :login, :password

        before do
          Rails.cache.clear
        end

        context 'when subscription is active' do
          before do
            stub_request(:get, 'https://scc.suse.com/connect/systems/subscriptions').to_return(status: 200, body: [body_active].to_json, headers: {})
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(200) }
        end

        context 'when subscription is expired' do
          before do
            stub_request(:get, 'https://scc.suse.com/connect/systems/subscriptions').to_return(status: 200, body: [body_expired].to_json, headers: {})
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end

        context 'when SCC request fails' do
          before do
            stub_request(:get, 'https://scc.suse.com/connect/systems/subscriptions').to_return(status: 401, body: [body_expired].to_json, headers: {})
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end
      end

      context 'with instance_data headers and instance data is valid' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': 'test' }) }

        before do
          Rails.cache.clear
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(true)
          get '/api/auth/check', headers: headers
        end

        it { is_expected.to have_http_status(200) }
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
