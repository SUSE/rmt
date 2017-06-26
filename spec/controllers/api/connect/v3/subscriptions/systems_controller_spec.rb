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
      expect(response.status).to eq 201
      expect(json_response[:login]).to start_with 'SCC_'
      expect(json_response.keys).to include :password
    end

    it 'succeeds with additional parameters' do
      post subject, params: { payload: { hostname: 'testhost' } }.to_json, headers: headers
      expect(response.status).to eq 201
      expect(json_response[:login]).to start_with 'SCC_'
      expect(json_response.keys).to include :password
    end

    it 'allows to register several systems' do
      headers # to eagerly load all required factories before actual test
      System.delete_all # to remove excessive systems created by factories

      3.times do |i|
        post subject, params: { hostname: "testhost#{i}" }.to_json, headers: headers
      end

      expect(System.count).to eq(3)
      expect(System.pluck(:hostname)).to match_array(%w(testhost0 testhost1 testhost2))
    end
  end
end
