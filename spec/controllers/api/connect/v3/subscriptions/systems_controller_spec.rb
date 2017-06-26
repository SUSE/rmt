require 'rails_helper'

RSpec.describe Api::Connect::V4::Subscriptions::SystemsController, type: [:request, :controller] do
  describe 'announce' do
    subject { connect_systems_url(format: :json) }

    before do
      post subject
    end

    it 'produces valid response status' do
      expect(response).to be_success
    end

    it 'contains username and password' do
      expect(json_response.keys).to include :username, :password
    end
  end
end
