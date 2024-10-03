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
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
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
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end

        context 'when product is not activated' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_not_activated].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }
        end

        context 'when status from SCC is unknown' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_unknown_status].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
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
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
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
        let(:scc_systems_activations_url) { 'https://scc.suse.com/connect/systems/activations' }
        let(:system_hybrid) { FactoryBot.create(:system, :hybrid, :with_activated_product) }
        let(:requested_uri) { '/repo' + system_hybrid.repositories.first[:local_path] + '/repodata/repomd.xml' }
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': 'test' }) }

        before do
          Rails.cache.clear
          allow(InstanceVerification).to receive(:update_cache)
          allow(Dir).to receive(:mkdir)
          allow(FileUtils).to receive(:touch)
        end

        context 'when subscription is active' do
          let(:body_active) do
            {
              id: 1,
              regcode: '631dc51f',
              name: 'Subscription 1',
              type: 'FULL',
              status: 'ACTIVE',
              starts_at: 'null',
              expires_at: DateTime.parse((Time.zone.today + 1).to_s),
              system_limit: 6,
              systems_count: 1,
              service: {
                product: {
                  id: system_hybrid.activations.first.product.id,
                  product_class: system_hybrid.activations.first.product.product_class + '-LTSS'
                }
              }
            }
          end
          let(:headers) { auth_header }

          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_active].to_json, headers: {})
            # allow(SccProxy).to receive(:get_scc_activations).and_return(status: 200, body: [body_active].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'hybrid' })
            allow(File).to receive(:directory?).and_return(true)
            allow(Dir).to receive(:mkdir)
            allow(FileUtils).to receive(:touch)
            # get '/api/auth/check', headers: headers
          end

          it 'returns true' do
            result = SccProxy.scc_check_subscription_expiration(
              headers,
              system_hybrid.login,
              system_hybrid.system_token,
              system_hybrid.proxy_byos_mode,
              system_hybrid.activations.first.product.product_class + '-LTSS'
            )
            expect(result[:is_active]).to be(true)
          end
        end

        context 'when subscription is expired' do
          let(:body_expired) do
            {
              id: 1,
              regcode: '631dc51f',
              name: 'Subscription 1',
              type: 'FULL',
              status: 'EXPIRED',
              starts_at: 'null',
              expires_at: DateTime.parse((Time.zone.today - 1).to_s),
              system_limit: 6,
              systems_count: 1,
              service: {
                product: {
                  id: system_hybrid.activations.first.product.id,
                  product_class: system_hybrid.activations.first.product.product_class + '-LTSS'
                }
              }
            }
          end

          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_expired].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'hybrid' })
            allow(File).to receive(:directory?).and_return(true)
            allow(Dir).to receive(:mkdir)
            allow(FileUtils).to receive(:touch)
          end

          it 'returns false, expired' do
            result = SccProxy.scc_check_subscription_expiration(
              headers,
              system_hybrid.login,
              system_hybrid.system_token,
              system_hybrid.proxy_byos_mode,
              system_hybrid.activations.first.product.product_class + '-LTSS'
            )
            expect(result[:is_active]).to eq(false)
            expect(result[:message]).to eq('Subscription expired.')
          end
        end

        context 'when product is not activated' do
          let(:body_not_activated) do
            {
              id: 1,
              regcode: '631dc51f',
              name: 'Subscription 1',
              type: 'FULL',
              status: 'FOO',
              starts_at: 'null',
              expires_at: DateTime.parse((Time.zone.today - 1).to_s),
              system_limit: 6,
              systems_count: 1,
              service: {
                product: {
                  id: system_hybrid.activations.first.product.id,
                  product_class: nil
                }
              }
            }
          end

          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_not_activated].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'hybrid' })
            allow(File).to receive(:directory?).and_return(true)
            allow(Dir).to receive(:mkdir)
            allow(FileUtils).to receive(:touch)
          end

          it 'returns product not activated' do
            result = SccProxy.scc_check_subscription_expiration(
              headers,
              system_hybrid.login,
              system_hybrid.system_token,
              system_hybrid.proxy_byos_mode,
              system_hybrid.activations.first.product.product_class + '-LTSS'
            )
            expect(result[:is_active]).to eq(false)
            expect(result[:message]).to eq('Product not activated.')
          end
        end

        context 'when unexpected error' do
          let(:body_unexpected) do
            {
              id: 1,
              regcode: '631dc51f',
              name: 'Subscription 1',
              type: 'FULL',
              status: 'FOO',
              starts_at: 'null',
              expires_at: DateTime.parse((Time.zone.today - 1).to_s),
              system_limit: 6,
              systems_count: 1,
              service: {
                product: {
                  id: system_hybrid.activations.first.product.id,
                  product_class: system_hybrid.activations.first.product.product_class
                }
              }
            }
          end

          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_unexpected].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'hybrid' })
            allow(File).to receive(:directory?).and_return(true)
            allow(Dir).to receive(:mkdir)
            allow(FileUtils).to receive(:touch)
          end

          it 'returns unexpected error' do
            result = SccProxy.scc_check_subscription_expiration(
              headers,
              system_hybrid.login,
              system_hybrid.system_token,
              system_hybrid.proxy_byos_mode,
              system_hybrid.activations.first.product.product_class + '-LTSS'
            )
            expect(result[:is_active]).to eq(false)
            expect(result[:message]).to eq('Unexpected error when checking product subscription.')
          end
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
            expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(true)
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
            expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(true)
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
