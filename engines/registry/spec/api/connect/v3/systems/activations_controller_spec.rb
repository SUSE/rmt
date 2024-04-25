describe Api::Connect::V3::Systems::ActivationsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activations for Registry' do
    let(:system) { FactoryBot.create(:system, :with_activated_product) }
    let(:headers) { auth_header.merge(version_header) }

    context 'without X-Instance-Data headers or hw_info' do
      it 'No instance metadata verification and no cache update' do
        get '/connect/systems/activations', headers: headers
        expect(ZypperAuth).not_to receive(:verify_instance)
        expect(FileUtils).not_to receive(:touch)
      end
    end

    context 'with invalid X-Instance-Data headers' do
      let(:headers) { auth_header.merge(version_header).merge({ 'X-Instance-Data' => 'instance_data' }) }

      it 'Instance metadata verification and no cache update' do
        expect(ZypperAuth).to receive(:verify_instance)
        expect(FileUtils).not_to receive(:touch)
        get '/connect/systems/activations', headers: headers
      end
    end

    context 'with X-Instance-Data headers' do
      let(:headers) { auth_header.merge(version_header).merge({ 'X-Instance-Data' => 'instance_data' }) }

      it 'verify the instance metadata and update the cache' do
        expect(FileUtils).to receive(:touch)
        allow(File).to receive(:join).and_return('foo')

        allow(FileUtils).to receive(:mkdir_p)
        allow(ZypperAuth).to receive(:verify_instance).and_return(true)
        get '/connect/systems/activations', headers: headers
      end
    end
  end
end
