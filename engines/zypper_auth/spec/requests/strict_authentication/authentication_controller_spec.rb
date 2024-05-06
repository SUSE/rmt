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
          allow(FileUtils).to receive(:mkdir_p)
          allow(FileUtils).to receive(:touch)
          get '/api/auth/check', headers: headers
        end

        it { is_expected.to have_http_status(403) }
      end

      context 'with instance_data headers and instance data is invalid' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': 'test' }) }

        before do
          Rails.cache.clear
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(false)
          allow(FileUtils).to receive(:mkdir_p)
          allow(FileUtils).to receive(:touch)
          get '/api/auth/check', headers: headers
        end

        it do
          is_expected.to have_http_status(403)
        end
      end

      context 'when system is BYOS proxy' do
        let(:local_path) { system_byos.activations.first.product.repositories.first.local_path }
        let(:requested_uri_byos) { '/repo' + local_path + '/repodata/repomd.xml' }
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri_byos, 'X-Instance-Data': 'test' }) }
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
            service: {
              product: {
                id: system_byos.activations.first.product.id
              }
            }
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
            service: {
              product: {
                id: system_byos.activations.first.product.id
              }
            }
          }
        end
        let(:body_not_activated) do
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
            service: {
              product: {
                id: 0o0000
              }
            }
          }
        end
        let(:body_unknown_status) do
          {
            id: 1,
            regcode: '631dc51f',
            name: 'Subscription 1',
            type: 'FULL',
            status: 'FOO',
            starts_at: 'null',
            expires_at: '2014-03-14T13:10:21.164Z',
            system_limit: 6,
            systems_count: 1,
            service: {
              product: {
                id: 0o0000
              }
            }
          }
        end
        let(:system_byos) { FactoryBot.create(:system, :byos, :with_activated_product, :with_system_information) }
        let(:scc_systems_activations_url) { 'https://scc.suse.com/connect/systems/activations' }

        include_context 'auth header', :system_byos, :login, :password

        before do
          Rails.cache.clear
        end

        context 'when subscription is active' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_active].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos: true })
            allow(FileUtils).to receive(:mkdir_p)
            allow(FileUtils).to receive(:touch)
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(200) }
        end

        context 'when subscription is expired' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_expired].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos: true })
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end

        context 'when product is not activated' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_not_activated].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos: true })
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end

        context 'when status from SCC is unknown' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_unknown_status].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos: true })
            allow(FileUtils).to receive(:mkdir_p)
            allow(FileUtils).to receive(:touch)
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end

        context 'when SCC request fails' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 401, body: [body_expired].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos: true })
            allow(FileUtils).to receive(:mkdir_p)
            allow(FileUtils).to receive(:touch)
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
          allow(FileUtils).to receive(:mkdir_p)
          allow(FileUtils).to receive(:touch)
          get '/api/auth/check', headers: headers
        end

        it { is_expected.to have_http_status(200) }
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
