require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController, type: [:request, :controller] do
  subject { '/connect/systems' }

  let(:system) { FactoryGirl.create(:system, hostname: 'initial') }

  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3
  let(:headers) { auth_header.merge(version_header) }

  let(:payload) { { hostname: 'test', hwinfo: { arch: 'x86_64' } } }

  context 'update' do
    it 'updates hostname of an existing system' do
      put subject, params: payload, headers: headers
      system.reload
      expect(response.body).to be_empty
      expect(response.status).to eq 204
      expect(system.hostname).to eq payload[:hostname]
    end

    # TODO: it 'updates hwinfo of an existing system' do

    it 'works without hostname provided' do
      payload = { hwinfo: { arch: 'x86_64' } }
      put subject, params: payload, headers: headers
      expect(response.status).to eq 204

      system.reload
      expect(system.hostname).to eq 'Not provided' # FIXME: SMT should detect the hostname instead
    end
  end
end
