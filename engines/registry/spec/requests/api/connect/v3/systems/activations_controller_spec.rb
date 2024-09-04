describe Api::Connect::V3::Systems::ActivationsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activations' do
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
          expect(SccProxy).not_to receive(:product_path_access)
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
          expect(SccProxy).not_to receive(:product_path_access)
          expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
        end
      end
    end
  end
end
