# rubocop:disable Metrics/ModuleLength
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
          allow_any_instance_of(AuthenticatedClient).to receive(:cache_file_exist?).and_return(true)
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
      let(:auth_headers_token) { {} }

      let(:fake_response) { { repositories: repositories_returned } }
      let(:repositories_returned) do
        %w[repo repo.v2 level1/repo.v2 level1/level2 level1/level2/repo level1/level2/level.3 level1/level2/level.3/repo]
      end
      let(:authorize_url) { 'api/registry/authorize' }
      let(:root_url) { 'smt-ec2.susecloud.net' }
      let(:access_policy_content) { File.read('engines/registry/spec/data/access_policy_yaml.yml') }
      let(:registry_conf) { { root_url: root_url } }


      context 'with valid credentials' do
        let(:system) { create(:system) }
        let(:auth_headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(system.login, system.password) } }
        let(:params_catalog) { "account=#{system.login}&scope=registry:catalog:*&service=SUSE%20Linux%20OCI%20Registry" }

        before do
          stub_request(:get, "https://registry-example.susecloud.net/api/registry/authorize?account=#{system.login}&scope=registry:catalog:*&service=SUSE%20Linux%20OCI%20Registry")
            .with(
              headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'User-Agent' => 'Ruby'
              }
            ).to_return(status: 200, body: JSON.dump({ foo: 'foo' }), headers: {})

          stub_request(:get, "#{RegistryCatalogService.new.catalog_api_url}?n=1000")
            .to_return(body: JSON.dump(fake_response), status: 200, headers: { 'Content-type' => 'application/json' })
        end

        context 'with a valid token' do
          it 'has catalog access' do
            allow(File).to receive(:read).and_return(access_policy_content)
            allow_any_instance_of(AuthenticatedClient).to receive(:cache_file_exist?).and_return(true)
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
          it 'denies the access' do
            get(
              '/api/registry/authorize',
              params: { service: 'SUSE Linux OCI Registry', scope: 'registry:catalog:*' },
              headers: auth_headers
              )

            auth_headers_token['Authorization'] = format('Bearer foo')

            get('/api/registry/catalog', headers: auth_headers_token)

            expect(response).to have_http_status(:unauthorized)
          end
        end

        context 'when an error happens' do
          it 'denies the access' do
            allow_any_instance_of(AccessScope).to receive(:allowed_paths).and_raise(StandardError, 'Foo')
            allow(File).to receive(:read).and_return(access_policy_content)
            allow_any_instance_of(AuthenticatedClient).to receive(:cache_file_exist?).and_return(true)
            get(
              '/api/registry/authorize',
              params: { service: 'SUSE Linux OCI Registry', scope: 'registry:catalog:*' },
              headers: auth_headers
              )

            auth_headers_token['Authorization'] = format("Bearer #{json_response[:token]}")
            get('/api/registry/catalog', headers: auth_headers_token)

            expect(response).to have_http_status(:unauthorized)
          end
        end
      end

      context 'with invalid credentials' do
        let(:system) { create(:system) }
        let(:auth_headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(system.login, system.password) } }
        let(:jwt_payload) do
          [
            {
              'iss' => 'RMT',
              'sub' => nil,
              'aud' => 'SUSE Linux OCI Registry',
              'exp' => 1724155172,
              'nbf' => 1724154872,
              'iat' => 1724154872,
              'jti' => 'NWRhY2VlYTAtNWE1Mi00NmYzLWI4MTEtZDdiYzRkYjE1OWRm',
              'access' => [{ 'type' => 'registry', 'class' => nil, 'name' => 'catalog', 'actions' => ['*'] }]
            },
            {
              'kid' => 'C7TL:6AHY:F4L2:PJT2:QSOT:AACT:QPDE:VPK3:3BEG:SJNF:Q52E:OIZR',
              'alg' => 'RS256'
            }
          ]
        end

        before do
          allow(JWT).to receive(:decode).and_return(jwt_payload)
          allow_any_instance_of(Registry::AuthenticatedClient).to receive(:cache_file_exist?).and_return(true)
          stub_request(:get, 'https://registry-example.susecloud.net/api/registry/authorize?&scope=registry:catalog:*&service=SUSE%20Linux%20OCI%20Registry')
            .with(
              headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'User-Agent' => 'Ruby'
              }
            ).to_return(status: 200, body: JSON.dump({ foo: 'foo' }), headers: {})

          stub_request(:get, "#{RegistryCatalogService.new.catalog_api_url}?n=1000")
            .to_return(body: JSON.dump(fake_response), status: 200, headers: { 'Content-type' => 'application/json' })
        end

        context 'with a valid token' do
          it 'can not find system' do
            allow(File).to receive(:read).and_return(access_policy_content)
            allow_any_instance_of(AuthenticatedClient).to receive(:cache_file_exist?).and_return(true)
            get(
              '/api/registry/authorize',
              params: { service: 'SUSE Linux OCI Registry', scope: 'registry:catalog:*' },
              headers: auth_headers
              )

            auth_headers_token['Authorization'] = format("Bearer #{json_response[:token]}")
            get('/api/registry/catalog', headers: auth_headers_token)

            expect(response).to have_http_status(:unauthorized)
            expect(JSON.parse(body)['error']).to eq('Please, re-authenticate')
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
