require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:url) { '/connect/systems' }
  let(:headers) { auth_header.merge(version_header) }
  let(:system) { FactoryGirl.create(:system, hostname: 'initial') }
  let(:payload) { { hostname: 'test', hwinfo: { arch: 'x86_64' } } }

  describe '#update' do
    context 'when hostname is provided' do
      subject { system }

      before do
        put url, params: payload, headers: headers
        system.reload
      end

      its(:hostname) { is_expected.to eq payload[:hostname] }

      describe 'HTTP response' do
        subject { response }
        its(:body) { is_expected.to be_empty }
        its(:status) { is_expected.to eq 204 }
      end
    end

    context 'when hostname is not provided' do
      subject { system }
      let(:payload) { { hwinfo: { arch: 'x86_64' } } }

      before do
        put url, params: payload, headers: headers
        system.reload
      end

      its(:hostname) { is_expected.to eq 'Not provided' } # FIXME: should detect the hostname instead

      describe 'HTTP response' do
        subject { response }
        its(:body) { is_expected.to be_empty }
        its(:status) { is_expected.to eq 204 }
      end
    end
  end

  describe '#deregister' do
    subject { system }

    before { delete url, params: payload, headers: headers }

    it 'system is deregistered' do
      expect { system.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  # TODO: it 'updates hwinfo of an existing system' do
end
