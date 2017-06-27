require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::ActivationsController, type: [:request, :controller] do
  include_context 'version header', 3
  let(:auth_mech) { ActionController::HttpAuthentication::Basic }

  describe '#index' do
    subject { connect_systems_activations_url(format: :json) }
    let(:system) { FactoryGirl.create :system_with_activated_base_product }
    let(:header) do
      { 'HTTP_AUTHORIZATION' => auth_mech.encode_credentials(system.login, system.password) }.merge(version_header)
    end

    it 'returns code 200' do
      get subject, headers: header

      expect(response.code).to eq('200')
    end

    it 'has valid JSON structure' do # TODO: JSON schema tests
      get subject, headers: header

      json_response.each do |element|
        expect(element).to have_key(:service)
      end
    end
  end
end
