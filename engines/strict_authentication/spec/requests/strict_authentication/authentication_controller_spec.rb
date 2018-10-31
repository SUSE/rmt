require 'rails_helper'

module StrictAuthentication
  RSpec.describe AuthenticationController, type: :request do
    subject { response }

    let(:system) { FactoryGirl.create(:system) }

    describe '#check' do
      context 'without authentication' do
        before { get '/api/auth/check' }
        its(:code) { is_expected.to eq '401' }
      end

      context 'with invalid credentials' do
        before { get '/api/auth/check', headers: basic_auth_header('invalid', 'invalid') }
        its(:code) { is_expected.to eq '401' }
      end

      context 'with valid credentials' do
        include_context 'auth header', :system, :login, :password

        before { get '/api/auth/check', headers: auth_header }
        its(:code) { is_expected.to eq '200' }
      end
    end
  end
end
