require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::ActivationsController do
  include_context 'version header', 3
  let(:auth_mech) { ActionController::HttpAuthentication::Basic }

  describe '#index' do
    let(:url) { connect_systems_activations_url(format: :json) }
    let(:system) { FactoryGirl.create(:system, :with_activated_base_product) }
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
  end
end
