require 'rails_helper'

RSpec.describe Api::Connect::BaseController, type: :controller do
  let(:subscription) { FactoryBot.create(:subscription) }
  let(:system) { FactoryBot.create(:system) }

  # Anonymous controller to test Api::Connect::BaseController
  controller do
    before_action :authenticate_system, only: :service
    before_action :authenticate_with_token, only: :announce_system

    def service
      head :not_found
    end

    def announce_system
      head :created
    end

    def activate
    end

    private

    def require_product
      require_params(%i[identifier version arch])
    end
  end

  before do
    routes.draw do
      get 'service' => 'api/connect/base#service'
      post 'announce_system' => 'api/connect/base#announce_system'
      post 'activate' => 'api/connect/base#activate'
    end
  end

  describe '#authenticate_system' do
    context 'with invalid credentials' do
      it 'authentication fails with wrong credentials' do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(system.login, '')

        get :service, params: { id: 1 }

        expect(response.media_type).to eq 'application/json'
        expect(response.status).to eq 401
        expect(json_response[:error]).to eq 'Invalid system credentials'
      end
    end

    context 'with valid credentials' do
      before { request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(system.login, system.password) }

      it 'authenticates the system with HTTP Basic Authentication' do
        get :service, params: { id: 1 }
        expect(response.status).to eq 404
      end

      it 'updates last_seen_at' do
        time = Time.zone.now.round(0) # rounding to ms to match mysql precision
        system.update(last_seen_at: 1.hour.ago)
        Timecop.freeze(time) do
          get :service, params: { id: 1 }

          expect(system.reload.last_seen_at).to eq Time.zone.now
        end
      end

      it 'sets last_seen_at if not yet set' do
        time = Time.zone.now.round(0) # rounding to ms to match mysql precision
        system.update(last_seen_at: nil)
        Timecop.freeze(time) do
          get :service, params: { id: 1 }

          expect(system.reload.last_seen_at).to eq Time.zone.now
        end
      end

      it "doesn't update last_seen_at if updated in the last 3 minutes" do
        time = 1.minute.ago.round(0) # rounding to ms to match mysql precision
        system.update(last_seen_at: time)
        get :service, params: { id: 1 }
        expect(system.reload.last_seen_at).to eq time
      end
    end

    context 'system token' do
      before do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic
          .encode_credentials(system.login, system.password)
      end

      let(:new_system_token) { 'BBBBBBBB-BBBB-4BBB-9BBB-BBBBBBBBBBBB' }

      context 'when the system does not have a token and the header is not present' do
        let(:system) { create(:system, hostname: 'system') }

        include_examples 'does not create a duplicate system'
        include_examples "does not update the old system's token"
        include_examples 'does not respond with a token'
      end

      context 'when the system does not have a token and the header is blank' do
        before { request.headers['System-Token'] = '' }

        let(:current_system_token) { nil }
        let(:system) { create(:system, hostname: 'system') }

        include_examples 'does not create a duplicate system'
        include_examples 'updates the system token'
        include_examples 'responds with a new token'
      end

      context 'when the system has a token and the header matches it' do
        before { request.headers['System-Token'] = current_system_token }

        let(:current_system_token) { 'AAAAAAAA-AAAA-4AAA-9AAA-AAAAAAAAAAAA' }
        let(:system) { create(:system, hostname: 'system', system_token: current_system_token) }

        include_examples 'does not create a duplicate system'
        include_examples 'updates the system token'
        include_examples 'responds with a new token'
      end

      context 'when the system has a token and the header is blank' do
        before { request.headers['System-Token'] = '' }

        let(:current_system_token) { 'AAAAAAAA-AAAA-4AAA-9AAA-AAAAAAAAAAAA' }
        let(:system) do
          create(:system, :with_activated_product, hostname: 'system',
                 system_token: current_system_token)
        end

        include_examples "does not update the old system's token"
        include_examples 'creates a duplicate system'
        include_examples 'responds with a new token'
      end

      context 'when the system has a token and the header does not match it' do
        before { request.headers['System-Token'] = wrong_system_token }

        let(:current_system_token) { 'AAAAAAAA-AAAA-4AAA-9AAA-AAAAAAAAAAAA' }
        let(:wrong_system_token)   { 'CCCCCCCC-CCCC-4CCC-9CCC-CCCCCCCCCCCC' }
        let(:system) do
          create(:system, :with_activated_product, hostname: 'system',
                 system_token: current_system_token)
        end

        include_examples "does not update the old system's token"
        include_examples 'creates a duplicate system'
        include_examples 'responds with a new token'
      end
    end
  end

  describe 'HTTP Token Authentication' do
    context 'with invalid credentials' do
      it 'authentication fails with wrong token' do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials('token')

        post :announce_system, params: { format: :json }

        expect(response.media_type).to eq 'application/json'
        expect(response.status).to eq 401
        expect(json_response[:error]).to eq 'Unknown Registration Code.'
      end
    end

    context 'with valid credentials' do
      it 'authenticates the system with valid token' do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials(subscription.regcode)

        post :announce_system, params: { email: 'glue-dummy@mail.com'.to_json, format: :json }

        expect(response.media_type).to eq 'application/json'
        expect(response.status).to eq 201
      end
    end
  end
end
