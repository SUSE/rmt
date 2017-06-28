require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::ActivationsController, type: [:request, :controller] do
  include_context 'version header', 3
  let(:auth_mech) { ActionController::HttpAuthentication::Basic }

  describe '#index' do
    let(:url) { connect_systems_activations_url(format: :json) }
    let(:system) { FactoryGirl.create :system_with_activated_base_product }
    let(:unauthenticated_headers) { version_header }
    let(:authenticated_headers) do
      { 'HTTP_AUTHORIZATION' => auth_mech.encode_credentials(system.login, system.password) }.merge(version_header)
    end

    context 'when authenticated' do
      before { get url, headers: unauthenticated_headers }
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
            expect(element).to have_key(:service)
          end
        end
      end
    end
  end
end
