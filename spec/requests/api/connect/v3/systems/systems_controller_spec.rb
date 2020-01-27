require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:system) { FactoryGirl.create(:system, :with_hw_info, hostname: 'initial') }
  let(:url) { '/connect/systems' }
  let(:headers) { auth_header.merge(version_header) }
  let(:hwinfo) do
    {
      cpus: 16,
      sockets: 1,
      arch: 'x86_64',
      hypervisor: 'XEN',
      uuid: 'f46906c5-d87d-4e4c-894b-851e80376003',
      cloud_provider: 'testcloud'
    }
  end
  let(:payload) { { hostname: 'test', hwinfo: hwinfo } }

  describe '#update' do
    subject(:update_action) { put url, params: payload, headers: headers }

    context 'when hostname is provided' do
      it do
        expect { update_action }.to change { system.reload.hostname }.from('initial').to(payload[:hostname])
      end

      it do
        update_action

        expect(system.reload.hostname).to eq('test')
        expect(response.body).to be_empty
        expect(response.status).to eq(204)
      end

      context 'hardware info' do
        context 'with existing hardware info' do
          it do
            update_action

            expect(system.hw_info.reload.arch).to eq('x86_64')
            expect(system.hw_info.reload.hypervisor).to eq('XEN')
            expect(system.hw_info.reload.uuid).to eq('f46906c5-d87d-4e4c-894b-851e80376003')
            expect(system.hw_info.reload.cloud_provider).to eq('testcloud')
          end

          it 'updates initial hardware info' do
            expect { update_action }.to change { system.hw_info.reload.cpus }.from(2).to(16)
          end
        end

        context 'with new hardware info' do
          let(:system) { FactoryGirl.create(:system, hostname: 'initial') }

          it do
            update_action

            expect(system.hw_info.reload.arch).to eq('x86_64')
            expect(system.hw_info.reload.hypervisor).to eq('XEN')
            expect(system.hw_info.reload.uuid).to eq('f46906c5-d87d-4e4c-894b-851e80376003')
            expect(system.hw_info.reload.cloud_provider).to eq('testcloud')
          end

          it 'creates hardware info record' do
            expect { update_action }.to change { HwInfo.count }.by(1)
          end
        end
      end
    end

    context 'when hostname is not provided' do
      let(:payload) { { hwinfo: hwinfo } }

      it do
        update_action

        expect(system.reload.hostname).to eq('Not provided') # FIXME: should detect the hostname instead
        expect(response.body).to be_empty
        expect(response.status).to eq(204)
      end

      context 'hardware info' do
        it do
          update_action

          expect(system.hw_info.reload.arch).to eq('x86_64')
          expect(system.hw_info.reload.hypervisor).to eq('XEN')
          expect(system.hw_info.reload.uuid).to eq('f46906c5-d87d-4e4c-894b-851e80376003')
          expect(system.hw_info.reload.cloud_provider).to eq('testcloud')
        end

        it 'updates initial hardware info' do
          expect { update_action }.to change { system.hw_info.reload.cpus }.from(2).to(16)
        end
      end
    end
  end

  describe '#deregister' do
    before do
      system # this will call `let()` block for :system
    end

    subject(:deregister_action) { delete url, params: payload, headers: headers }

    it 'deletes system' do
      expect { deregister_action }.to change { System.count }.by(-1)
    end

    it 'deletes hardware info' do
      expect { deregister_action }.to change { HwInfo.count }.by(-1)
    end
  end
end
