require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:system) { FactoryGirl.create(:system, :with_hw_info, hostname: 'initial') }
  let(:url) { '/connect/systems' }
  let(:headers) { auth_header.merge(version_header) }
  let(:payload) { { hostname: 'test', hwinfo: { cpus: 16, sockets: 1, arch: 'x86_64', hypervisor: 'XEN', uuid: 'f46906c5-d87d-4e4c-894b-851e80376003' } } }

  describe '#update' do
    subject { put url, params: payload, headers: headers }

    context 'when hostname is provided' do
      it do
        expect { subject }.to change { system.reload.hostname }.from('initial').to(payload[:hostname])
      end

      it do
        subject

        expect(system.reload.hostname).to eq('test') # FIXME: should detect the hostname instead
        expect(response.body).to be_empty
        expect(response.status).to eq(204)
      end

      context 'hardware info' do
        it do
          subject

          expect(system.hw_info.reload.arch).to eq('x86_64')
          expect(system.hw_info.reload.hypervisor).to eq('XEN')
          expect(system.hw_info.reload.uuid).to eq('f46906c5-d87d-4e4c-894b-851e80376003')
        end

        it 'should update initial hardware info' do
          expect { subject }.to change { system.hw_info.reload.cpus }.from(2).to(16)
        end
      end
    end

    context 'when hostname is not provided' do
      let(:payload) { { hwinfo: { cpus: 16, sockets: 1, arch: 'x86_64', hypervisor: 'XEN', uuid: 'f46906c5-d87d-4e4c-894b-851e80376003' } } }

      it do
        subject

        expect(system.reload.hostname).to eq('Not provided') # FIXME: should detect the hostname instead
        expect(response.body).to be_empty
        expect(response.status).to eq(204)
      end

      context 'hardware info' do
        it do
          subject

          expect(system.hw_info.reload.arch).to eq('x86_64')
          expect(system.hw_info.reload.hypervisor).to eq('XEN')
          expect(system.hw_info.reload.uuid).to eq('f46906c5-d87d-4e4c-894b-851e80376003')
        end

        it 'should update initial hardware info' do
          expect { subject }.to change { system.hw_info.reload.cpus }.from(2).to(16)
        end
      end
    end
  end

  describe '#deregister' do
    before do
      system # this will call `let() block for :system`
    end

    subject { delete url, params: payload, headers: headers }

    it 'should delete system' do
      expect { subject }.to change { System.count }.by(-1)
    end

    it 'should delete hardware info' do
      expect { subject }.to change { HwInfo.count }.by(-1)
    end
  end
end
