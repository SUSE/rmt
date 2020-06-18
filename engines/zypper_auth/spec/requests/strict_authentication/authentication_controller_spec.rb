require 'rails_helper'

describe StrictAuthentication::AuthenticationController, type: :request do
  subject { response }

  let(:system) { FactoryGirl.create(:system, :with_activated_product) }

  describe '#check' do
    context 'with valid credentials' do
      include_context 'auth header', :system, :login, :password

      let(:requested_uri) { '/repo' + system.repositories.first[:local_path] + '/repodata/repomd.xml' }

      context 'without instance_data headers' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri }) }

        before do
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(false)
          get '/api/auth/check', headers: headers
        end

        it { is_expected.to have_http_status(403) }
      end

      context 'with instance_data headers and instance data is invalid' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': 'test' }) }

        before do
          Rails.cache.clear
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(false)
          get '/api/auth/check', headers: headers
        end

        it do
          is_expected.to have_http_status(403)
        end
      end

      context 'with instance_data headers and instance data is valid' do
        let(:headers) { auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': 'test' }) }

        before do
          Rails.cache.clear
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(true)
          get '/api/auth/check', headers: headers
        end

        it { is_expected.to have_http_status(200) }
      end
    end
  end
end
