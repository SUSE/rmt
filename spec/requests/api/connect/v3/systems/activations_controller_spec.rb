require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::ActivationsController do
  include_context 'version header', 3
  let(:auth_mech) { ActionController::HttpAuthentication::Basic }

  describe '#index' do
    let(:url) { connect_systems_activations_url(format: :json) }
    let(:system) { FactoryBot.create(:system, :with_activated_base_product) }
    let(:unauthenticated_headers) { version_header }
    let(:wrong_credentials_headers) do
      { 'HTTP_AUTHORIZATION' => auth_mech.encode_credentials('wrong_login', 'wrong_password') }.merge(version_header)
    end
    let(:authenticated_headers) do
      { 'HTTP_AUTHORIZATION' => auth_mech.encode_credentials(system.login, system.password) }.merge(version_header)
    end

    context 'when not authenticated' do
      before { get url, headers: unauthenticated_headers }
      subject { response }

      its(:code) { is_expected.to eq '401' }
    end

    context 'when credentials are wrong' do
      before { get url, headers: wrong_credentials_headers }
      subject { response }

      its(:code) { is_expected.to eq '401' }
    end

    context 'when authenticated' do
      before { get url, headers: authenticated_headers }
      subject { response }

      its(:code) { is_expected.to eq '200' }

      describe 'JSON in response' do
        it 'has valid structure' do # TODO: JSON schema tests
          json_response.each do |element|
            expect(element).to match(
              hash_including({
                service: hash_including({
                  product: hash_including(:repositories)
                })
              })
            )
          end
        end

        it 'has valid credentials parameter in the URL' do
          json_response.each do |element|
            expect(element[:service][:url]).to match(/\?credentials=#{element[:service][:name]}/)
          end
        end
      end
    end

    context 'last_seen_at check' do
      it 'does not touch scc_synced_at when it simply authenticates' do
        expect(system.last_seen_at).to be_nil

        get url, headers: authenticated_headers
        expect(response.code).to eq '200'

        system.reload

        expect(system.last_seen_at).not_to be_nil
        expect(system.scc_synced_at).to be_nil
      end
    end

    context 'system token header' do
      context 'when system token header is present in request' do
        let(:token_headers) do
          authenticated_headers.merge({ 'System-Token' => 'some_token' })
        end

        it 'sets system token in response headers' do
          get url, headers: token_headers
          expect(response.code).to eq '200'
          expect(response.headers).to include('System-Token')
          expect(response.headers['System-Token']).not_to be_nil
          expect(response.headers['System-Token']).not_to be_empty
        end

        it 'does not set system token header if no system token header in request' do
          get url, headers: authenticated_headers

          expect(response.code).to eq '200'
          expect(response.headers).not_to include('System-Token')
        end
      end
    end
  end
end
