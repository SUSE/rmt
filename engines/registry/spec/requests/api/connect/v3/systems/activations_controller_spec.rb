describe Api::Connect::V3::Systems::ActivationsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activations' do
    let(:system) { FactoryBot.create(:system, :with_activated_product) }
    let(:headers) { auth_header.merge(version_header) }

    before do
      headers['X-Instance-Data'] = 'IMDS'
      allow(ZypperAuth).to receive(:verify_instance).and_return(true)
      get '/connect/systems/activations', headers: headers
    end

    context 'without X-Instance-Data headers or hw_info' do
      it 'has service URLs with HTTP scheme' do
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
      end
    end
  end
end
