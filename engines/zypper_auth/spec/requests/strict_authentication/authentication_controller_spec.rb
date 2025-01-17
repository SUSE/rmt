require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
describe StrictAuthentication::AuthenticationController, type: :request do
  subject { response }

  let(:system) { FactoryBot.create(:system, :payg, :with_activated_product) }

  after { FileUtils.rm_rf(File.dirname(Rails.application.config.registry_cache_dir)) }

  describe '#check' do
    before { Thread.current[:logger] = RMT::Logger.new('/dev/null') }

    context 'with valid credentials' do
      include_context 'auth header', :system, :login, :password

      let(:requested_uri) { '/repo' + system.repositories.first[:local_path] + '/repodata/repomd.xml' }
      let(:paid_requested_uri) { '/repo' + system.products.where(free: false).first.repositories.first[:local_path] + '/repodata/repomd.xml' }

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
        let(:paid_local_path) do
          system_byos.activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.repositories.first.local_path
        end
        let(:requested_uri_byos) { '/repo' + local_path + '/repodata/repomd.xml' }
        let(:paid_requested_uri_byos) { '/repo' + paid_local_path + '/repodata/repomd.xml' }
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri_byos, 'X-Instance-Data': 'test' }) }
        let(:paid_headers) { auth_header.merge({ 'X-Original-URI': paid_requested_uri_byos, 'X-Instance-Data': 'test' }) }
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
                id: system_byos.products.find_by(product_type: 'base').id, # activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.id, # rubocop:disable Layout/LineLength
                product_class: system_byos.products.find_by(product_type: 'base').product_class # activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.product_class # rubocop:disable Layout/LineLength
              }
            }
          }
        end
        let(:body_active_byos_paid_extension) do
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
                id: system_byos.activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.id,
                product_class: system_byos.activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.product_class
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
                id: system_byos.activations.first.product.id,
                product_class: system_byos.activations.first.product.product_class
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
                id: 0o0000,
                product_class: 'foo'
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
                id: 0o0000,
                product_class: 'bar'
              }
            }
          }
        end
        let(:system_byos) { FactoryBot.create(:system, :byos, :with_activated_paid_extension) }
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

          context 'and repo is not free' do
            before do
              stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_active_byos_paid_extension].to_json, headers: {})
              expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
              get '/api/auth/check', headers: paid_headers
            end

            it { is_expected.to have_http_status(200) }
          end
        end

        context 'when subscription is expired' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_expired].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }

          context 'and repo is not free' do
            before do
              expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
              get '/api/auth/check', headers: paid_headers
            end

            it { is_expected.to have_http_status(403) }
          end
        end

        context 'when product is not activated' do
          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_not_activated].to_json, headers: {})
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
            get '/api/auth/check', headers: headers
          end

          it { is_expected.to have_http_status(403) }

          context 'and repo is not free' do
            before do
              expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
              get '/api/auth/check', headers: paid_headers
            end

            it { is_expected.to have_http_status(403) }
          end
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

          context 'and repo is not free' do
            before do
              expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
              get '/api/auth/check', headers: paid_headers
            end

            it { is_expected.to have_http_status(403) }
          end
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

          context 'and repo is not free' do
            before do
              expect(URI).to receive(:encode_www_form).with({ byos_mode: 'byos' })
              get '/api/auth/check', headers: paid_headers
            end

            it { is_expected.to have_http_status(403) }
          end
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
        let(:system_hybrid) { FactoryBot.create(:system, :hybrid, :with_activated_paid_extension) }
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
            expect(URI).to receive(:encode_www_form).with({ byos_mode: 'hybrid' })
            allow(File).to receive(:directory?).and_return(true)
            allow(Dir).to receive(:mkdir)
            allow(FileUtils).to receive(:touch)
          end

          it 'returns true' do
            result = SccProxy.scc_check_subscription_expiration(
              headers,
              system_hybrid,
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
              system_hybrid,
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
              system_hybrid,
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
                  id: system_hybrid.activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.id,
                  product_class: system_hybrid.activations.joins(:product).where(products: { free: false,
                                                                                             product_type: :extension }).first.product.product_class
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
              system_hybrid,
              system_hybrid.activations.first.product.product_class + '-LTSS'
            )
            expect(result[:is_active]).to eq(false)
            expect(result[:message]).to eq('Product not activated.')
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
                  id: system_hybrid.activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.id,
                  product_class: system_hybrid.activations.joins(:product).where(products: { free: false,
                                                                                             product_type: :extension }).first.product.product_class
                }
              }
            }
          end

          context 'the path to check is free' do
            before do
              expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(true)
              get '/api/auth/check', headers: headers
            end

            it { is_expected.to have_http_status(200) }
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
