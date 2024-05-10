describe Api::Connect::V3::Systems::ActivationsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activations' do
    let(:system) { FactoryBot.create(:system, :with_activated_product) }
    let(:headers) { auth_header.merge(version_header) }

    context 'without valid repository cache' do
      before do
        headers['X-Instance-Data'] = 'IMDS'
        allow(InstanceVerification).to receive(:verify_instance).and_return(true)
      end

      context 'without X-Instance-Data headers or hw_info' do
        it 'has service URLs with HTTP scheme' do
          get '/connect/systems/activations', headers: headers
          data = JSON.parse(response.body)
          expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
        end
      end
    end

    context 'with repository cache valid' do
      let(:cache_name) { "repo/cache/127.0.0.1-#{system.login}-#{system.products.first.id}" }

      before do
        allow(File).to receive(:join).and_call_original
        allow(File).to receive(:directory?)
        allow(Dir).to receive(:mkdir)
        allow(FileUtils).to receive(:touch)
        allow(InstanceVerification).to receive(:repository_cache_path).and_return('.')
        allow(InstanceVerification).to receive(:registry_cache_path)
        allow(InstanceVerification).to receive(:write_cache_file)
        allow(InstanceVerification).to receive(:update_cache)
        allow(InstanceVerification).to receive(:verify_instance).and_call_original
        headers['X-Instance-Data'] = 'IMDS'
      end

      it 'refreshes registry cache key only' do
        allow(File).to receive(:directory?)
        allow(Dir).to receive(:mkdir)
        expect(InstanceVerification).to receive(:update_cache).with('127.0.0.1', system.login, nil, is_byos: system.proxy_byos, registry: true)
        get '/connect/systems/activations', headers: headers
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
      end
    end
  end
end
