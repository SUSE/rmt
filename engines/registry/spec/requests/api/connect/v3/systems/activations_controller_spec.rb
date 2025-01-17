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
        let(:cache_name) { "repo/cache/127.0.0.1-#{system.login}-#{system.products.first.id}" }

        before do
          allow(File).to receive(:join).and_call_original
          allow(InstanceVerification).to receive(:update_cache)
          allow(ZypperAuth).to receive(:verify_instance).and_call_original
          headers['X-Instance-Data'] = 'IMDS'
        end

        it 'refreshes registry cache key only' do
          FileUtils.mkdir_p('repo/cache')
          FileUtils.touch(cache_name)
          expect(InstanceVerification).to receive(:update_cache).with('127.0.0.1', system.login, nil, registry: true)
          get '/connect/systems/activations', headers: headers
          FileUtils.rm_rf('repo/cache')
          data = JSON.parse(response.body)
          expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
        end
      end

      context 'system is hybrid' do
        let(:system) { FactoryBot.create(:system, :hybrid, :with_activated_product) }
        let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }
        let(:cache_name) { "repo/cache/127.0.0.1-#{system.login}-#{system.products.first.id}" }
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

        before do
          allow(InstanceVerification::Providers::Example).to receive(:new).and_return(plugin_double)

          allow(plugin_double).to(
            receive(:instance_valid?).and_return(true)
            )
          allow(File).to receive(:join).and_call_original
          allow(InstanceVerification).to receive(:update_cache)
          allow(ZypperAuth).to receive(:verify_instance).and_call_original
          stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_active].to_json, headers: {})
          headers['X-Instance-Data'] = 'IMDS'
        end

        context 'no registry' do
          it 'refreshes registry cache key only' do
            FileUtils.mkdir_p('repo/cache')
            expect(InstanceVerification).to receive(:update_cache).with('127.0.0.1', system.login, system.activations.first.product.id)
            get '/connect/systems/activations', headers: headers
            FileUtils.rm_rf('repo/cache')
            data = JSON.parse(response.body)
            expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
          end
        end

        context 'registry' do
          it 'refreshes registry cache key only' do
            FileUtils.mkdir_p('repo/cache')
            FileUtils.touch(cache_name)
            expect(InstanceVerification).to receive(:update_cache).with('127.0.0.1', system.login, nil, registry: true)
            get '/connect/systems/activations', headers: headers
            FileUtils.rm_rf('repo/cache')
            data = JSON.parse(response.body)
            expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
          end
        end
      end
    end

    context 'byos' do
      let(:system) { FactoryBot.create(:system, :byos, :with_activated_product) }
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
          let(:scc_response) do
            {
              is_active: true
            }
          end

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
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: [body_active].to_json, headers: {})
            allow(ZypperAuth).to receive(:verify_instance).and_call_original
            expect(InstanceVerification).to receive(:update_cache).with('127.0.0.1', system.login, system.activations.first.product.id)
            get '/connect/systems/activations', headers: headers

            data = JSON.parse(response.body)
            expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
            expect(data[0]['service']['id']).to match(system.activations.first.service_id)
            expect(data[0]['service']['product']['id']).to match(system.activations.first.service_id)
            expect(data[0]['id']).to match(system.activations.first.id)
            expect(data[0]['system_id']).to match(system.activations.first.system_id)
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
