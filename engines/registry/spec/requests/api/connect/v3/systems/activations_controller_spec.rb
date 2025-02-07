# rubocop:disable RSpec/NestedGroups
describe Api::Connect::V3::Systems::ActivationsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activations' do
    context 'payg' do
      let(:system) { FactoryBot.create(:system, :payg, :with_activated_product) }
      let(:headers) { auth_header.merge(version_header) }

      context 'without valid repository cache' do
        context 'without X-Instance-Data headers or hw_info' do
          it 'does not update InstanceVerification cache' do
            get '/connect/systems/activations', headers: headers
            data = JSON.parse(response.body)
            expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
            expect(InstanceVerification).not_to receive(:update_cache)
          end
        end

        context 'with X-Instance-Data headers and bad metadata' do
          let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

          before do
            headers['X-Instance-Data'] = 'IMDS'
            Thread.current[:logger] = RMT::Logger.new('/dev/null')
          end

          it 'does not update InstanceVerification cache' do
            FileUtils.rm_rf('registry/cache') if File.exist?('registry/cache')
            FileUtils.rm_rf('repo/payg/cache') if File.exist?('repo/payg/cache')
            allow(plugin_double).to(
              receive(:instance_valid?)
                .and_raise(InstanceVerification::Exception, 'Custom plugin error')
              )
            allow(ZypperAuth).to receive(:verify_instance).and_call_original
            get '/connect/systems/activations', headers: headers
            expect(response.body).to include('Instance verification failed')
            expect(InstanceVerification).not_to receive(:update_cache)
          end
        end
      end

      context 'with repository cache valid' do
        let(:cache_path) { "repo/#{system.proxy_byos_mode}/cache" }
        let(:cache_name) { "#{cache_path}/127.0.0.1-#{system.login}-#{system.products.first.id}" }

        before do
          allow(File).to receive(:join).and_call_original
          allow(InstanceVerification).to receive(:update_cache)
          allow(ZypperAuth).to receive(:verify_instance).and_call_original
          headers['X-Instance-Data'] = 'IMDS'
        end

        it 'refreshes registry cache key only' do
          FileUtils.mkdir_p(cache_path)
          FileUtils.touch(cache_name)
          expect(InstanceVerification).to receive(:update_cache).with(
            "127.0.0.1-#{system.login}-#{system.products.first.id}", system.proxy_byos_mode, registry: true
          )
          get '/connect/systems/activations', headers: headers
          FileUtils.rm_rf(cache_path)
          data = JSON.parse(response.body)
          expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
        end
      end

      context 'system is hybrid' do
        let(:system) { FactoryBot.create(:system, :hybrid, :with_activated_product, pubcloud_reg_code: Base64.strict_encode64('foo')) }
        let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }
        let(:cache_name) { "repo/payg/cache/127.0.0.1-#{system.login}-#{system.products.first.id}" }
        let(:scc_systems_activations_url) { 'https://scc.suse.com/connect/systems/activations' }
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
                id: system.activations.first.product.id
              }
            }
          }
        end
        let(:product_hash) { system.activations.first.product.attributes.symbolize_keys.slice(:identifier, :version, :arch) }
        let(:product_triplet) { "#{product_hash[:identifier]}_#{product_hash[:version]}_#{product_hash[:arch]}" }

        before do
          allow(InstanceVerification::Providers::Example).to receive(:new).and_return(plugin_double)

          allow(plugin_double).to(
            receive(:instance_valid?).and_return(true)
            )
          allow(InstanceVerification).to receive(:update_cache)
          allow(ZypperAuth).to receive(:verify_instance).and_call_original
          stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_active].to_json, headers: {})
          headers['X-Instance-Data'] = 'IMDS'
        end

        context 'no registry' do
          it 'refreshes registry cache key only' do
            allow(InstanceVerification).to receive(:reg_code_in_cache?).and_return(nil)
            FileUtils.mkdir_p('repo/payg/cache')
            expect(InstanceVerification).to receive(:update_cache).with(
              "#{system.pubcloud_reg_code}-#{product_triplet}-active",
              system.proxy_byos_mode
            )
            get '/connect/systems/activations', headers: headers
            FileUtils.rm_rf('repo/payg/cache')
            data = JSON.parse(response.body)
            expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
          end
        end

        context 'registry' do
          it 'refreshes registry cache key only' do
            allow(InstanceVerification).to receive(:reg_code_in_cache?).and_return(true)
            expect(InstanceVerification).to receive(:update_cache).with(
              "#{system.pubcloud_reg_code}-#{product_triplet}-active",
              system.proxy_byos_mode,
              registry: true
            )
            get '/connect/systems/activations', headers: headers
            FileUtils.rm_rf('repo/payg/cache')
            data = JSON.parse(response.body)
            expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
          end
        end
      end
    end

    context 'byos' do
      let(:system) { FactoryBot.create(:system, :byos, :with_activated_product, pubcloud_reg_code: Base64.strict_encode64('bar')) }
      let(:headers) { auth_header.merge(version_header) }
      let(:scc_systems_activations_url) { 'https://scc.suse.com/connect/systems/activations' }
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
              id: system.products.find_by(product_type: 'base').id, # activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.id, # rubocop:disable Layout/LineLength
              product_class: system.products.find_by(product_type: 'base').product_class # activations.joins(:product).where(products: { free: false, product_type: :extension }).first.product.product_class # rubocop:disable Layout/LineLength
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

      context 'without valid repository cache' do
        context 'with X-Instance-Data headers and bad metadata and good subscription on SCC' do
          let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }
          let(:product_hash) { system.activations.first.product.attributes.symbolize_keys.slice(:identifier, :version, :arch) }
          let(:product_triplet) { "#{product_hash[:identifier]}_#{product_hash[:version]}_#{product_hash[:arch]}" }

          before do
            allow(InstanceVerification).to receive(:update_cache)
            headers['X-Instance-Data'] = 'IMDS'
            Thread.current[:logger] = RMT::Logger.new('/dev/null')
          end

          it 'does update InstanceVerification cache' do
            allow(plugin_double).to(
              receive(:instance_valid?)
                .and_raise(InstanceVerification::Exception, 'Custom plugin error')
              )
            allow(InstanceVerification).to receive(:reg_code_in_cache?).and_return(nil)
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_active].to_json, headers: {})
            allow(ZypperAuth).to receive(:verify_instance).and_call_original
            expect(InstanceVerification).to receive(:update_cache).with("#{system.pubcloud_reg_code}-#{product_triplet}-active", 'byos')
            get '/connect/systems/activations', headers: headers

            data = JSON.parse(response.body)
            expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
            expect(data[0]['service']['id']).to match(system.activations.first.service_id)
            expect(data[0]['service']['product']['id']).to match(system.activations.first.service_id)
            expect(data[0]['id']).to match(system.activations.first.id)
            expect(data[0]['system_id']).to match(system.activations.first.system_id)
          end
        end

        context 'with X-Instance-Data headers and bad metadata and bad subscription on SCC' do
          let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }
          let(:product_hash) { system.activations.first.product.attributes.symbolize_keys.slice(:identifier, :version, :arch) }
          let(:product_triplet) { "#{product_hash[:identifier]}_#{product_hash[:version]}_#{product_hash[:arch]}" }
          let(:scc_response) do
            {
              is_active: false,
              message: 'error'
            }
          end

          before do
            allow(InstanceVerification).to receive(:update_cache)
            headers['X-Instance-Data'] = 'IMDS'
            Thread.current[:logger] = RMT::Logger.new('/dev/null')
          end

          it 'set InstanceVerification cache inactive' do
            allow(plugin_double).to(
              receive(:instance_valid?)
                .and_raise(InstanceVerification::Exception, 'Custom plugin error')
              )
            allow(InstanceVerification).to receive(:reg_code_in_cache?).and_return(nil)
            allow(SccProxy).to receive(:scc_check_subscription_expiration).and_return(scc_response)
            allow(ZypperAuth).to receive(:verify_instance).and_call_original
            expect(InstanceVerification).to receive(:update_cache).with("#{system.pubcloud_reg_code}-#{product_triplet}-inactive", 'byos')
            get '/connect/systems/activations', headers: headers

            expect(response.body).to include('Instance verification failed')
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
