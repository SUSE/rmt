require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
describe StrictAuthentication::AuthenticationController, type: :request do
  subject { response }

  let(:system) { FactoryBot.create(:system, :with_activated_product) }

  after { FileUtils.rm_rf(File.dirname(Rails.application.config.registry_cache_dir)) }

  describe '#check' do
    before { Thread.current[:logger] = RMT::Logger.new('/dev/null') }

    context 'with valid credentials' do
      include_context 'auth header', :system, :login, :password

      let(:requested_uri) { '/repo' + system.repositories.first[:local_path] + '/repodata/repomd.xml' }

      context 'without instance_data headers' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri }) }

        before do
          allow(File).to receive(:directory?)
          allow(Dir).to receive(:mkdir)
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
          allow(File).to receive(:directory?)
          allow(Dir).to receive(:mkdir)
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
            allow(File).to receive(:directory?).and_return(true)
            allow(Dir).to receive(:mkdir)
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
            allow(File).to receive(:directory?)
            allow(Dir).to receive(:mkdir)
            allow(FileUtils).to receive(:touch)
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end

        context 'when SCC request fails' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 401, body: [body_expired].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos: true })
            allow(File).to receive(:directory?)
            allow(Dir).to receive(:mkdir)
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
          allow(InstanceVerification).to receive(:update_cache)
          allow(File).to receive(:directory?)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
          get '/api/auth/check', headers: headers
        end

        it { is_expected.to have_http_status(200) }
      end

      context 'system is hybrid' do
        include_context 'auth header', :system_hybrid, :login, :password
        let(:system_hybrid) { FactoryBot.create(:system, :hybrid, :with_activated_product) }
        let(:requested_uri) { '/repo' + system_hybrid.repositories.first[:local_path] + '/repodata/repomd.xml' }
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': 'test' }) }

        before do
          Rails.cache.clear
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(true)
          allow(InstanceVerification).to receive(:update_cache)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
        end

        context 'regcode check fails' do
          let(:error_message) do
            "Access to the repos denied: #{scc_response[:message]}\nSystem login: #{system_hybrid.login}, IP: 127.0.0.1\n"
          end

          let(:scc_response) do
            {
              is_active: false,
              message: 'You shall not have access to those repos !'
            }
          end

          before do
            allow(SccProxy).to receive(:scc_check_subscription_expiration).and_return(scc_response)
            expect(SccProxy).to receive(:scc_check_subscription_expiration)
            allow(ZypperAuth.auth_logger).to receive(:info)
            expect(ZypperAuth.auth_logger).to receive(:info).with(error_message)
            expect(FileUtils).not_to receive(:touch)
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end

        context 'regcode check suceeds' do
          let(:scc_response) do
            {
              is_active: true
            }
          end

          before do
            allow(SccProxy).to receive(:scc_check_subscription_expiration).and_return(scc_response)
            expect(SccProxy).to receive(:scc_check_subscription_expiration)
            allow(ZypperAuth.auth_logger).to receive(:info)
            expect(ZypperAuth.auth_logger).not_to(receive(:info))
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(200) }
        end
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
