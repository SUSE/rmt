module Registry
  describe RegistryController, type: :request do
    describe '#authenticate' do
      context 'login request with invalid credentials' do
        let(:auth_headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials('login', 'password') } }

        it 'succeeds with login + password from secrets' do
          get('/api/registry/authorize', headers: auth_headers)

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'login request with valid credentials' do
        let(:system) { create(:system) }
        let(:auth_headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(system.login, system.password) } }

        it 'succeeds with login + password from secrets' do
          get('/api/registry/authorize', headers: auth_headers)

          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe '#catalog without access token' do
      let(:system) { create(:system) }
      let(:auth_headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(system.login, system.password) } }

      it 'returns 401' do
        get('/api/registry/catalog')
        expect(response).to have_http_status(:unauthorized)
        expect(response.header['WWW-Authenticate']).not_to include('error="insufficient_scope"')
      end

      it 'with a token that has no access to catalog' do
        get('/api/registry/authorize', params: { scope: '' }, headers: auth_headers)

        request.headers.merge({ 'HTTP_AUTHORIZATION' => "Bearer #{json_response[:token]}" })
        get('/api/registry/catalog', headers: auth_headers)

        expect(response.header['WWW-Authenticate']).to include('error="insufficient_scope"')
      end
    end

    describe '#catalog access' do
      let(:system) { create(:system) }
      let(:params) {
        {
          'account' => system.login,
          'scope'   => 'registry:catalog:*',
          'service' => 'SUSE Linux Docker Registry'
        }
      }
      let(:auth_headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(system.login, system.password) } }
      let(:auth_headers_token) { {} }

      let(:fake_response){ { repositories: repositories_returned } }
      let(:repositories_returned) do
        %w[repo repo.v2 level1/repo.v2 level1/level2 level1/level2/repo level1/level2/level.3 level1/level2/level.3/repo]
      end
      let(:auth_url) { 'https://smt-ec2.susecloud.net/api/registry/authorize' }
      let(:params) { "account=#{system.login}&scope=registry:catalog:*&service=SUSE%20Linux%20OCI%20Registry" }
      let(:access_policy_content) { File.read('engines/registry/spec/data/access_policy_yaml.yml') }

      before do
        stub_request(:get, "#{auth_url}?#{params}")
          .to_return(body: JSON.dump(fake_response), status: 200, headers: { 'Content-type' => 'application/json' })

        stub_request(:get, "#{RegistryCatalogService.new.catalog_api_url}?n=1000")
          .to_return(body: JSON.dump(fake_response), status: 200, headers: { 'Content-type' => 'application/json' })
      end

      context 'with a valid token' do
        it 'has catalog access' do
          allow(File).to receive(:read).and_return(access_policy_content)
          get(
            '/api/registry/authorize',
            params: { service: 'SUSE Linux OCI Registry', scope: 'registry:catalog:*' },
            headers: auth_headers
            )

          auth_headers_token['Authorization'] = format("Bearer #{json_response[:token]}")
          get('/api/registry/catalog', headers: auth_headers_token)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when token is invalid' do
        it 'raise an exception' do
          get(
            '/api/registry/authorize',
            params: { service: 'SUSE Linux OCI Registry', scope: 'registry:catalog:*' },
            headers: auth_headers
            )

          auth_headers_token['Authorization'] = format("Bearer foo")

          get('/api/registry/catalog', headers: auth_headers_token)

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
