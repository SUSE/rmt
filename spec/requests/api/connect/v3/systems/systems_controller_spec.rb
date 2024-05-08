require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:system) { FactoryBot.create(:system, hostname: 'initial') }
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
  let(:system_uptime) { system.system_uptimes.first }
  let(:online_hours) { ':111111111111111111111111' }
  let(:upd_online_hours) { ':111111111111111111111100' }

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

      context 'with existing hardware info' do
        it 'updates initial hardware info' do
          update_action

          information = JSON.parse(system.reload.system_information).symbolize_keys

          expect(system.reload.cloud_provider).to eq('testcloud')
          expect(information[:cpus]).to eq('16')
        end
      end

      context 'when uptime data provided' do
        let(:payload) { { hostname: 'test', hwinfo: hwinfo, online_at: [1.day.ago.to_date.to_s << online_hours] } }

        it 'inserts the uptime data in system_uptimes table' do
          update_action

          expect(system_uptime.system_id).to eq(system.reload.id)
          expect(system_uptime.online_at_day.to_date).to eq(1.day.ago.to_date)
          expect(system_uptime.online_at_hours.to_s).to eq('111111111111111111111111')
        end
      end

      context 'updates uptime data online_at_hours' do
        let(:payload) { { hostname: 'test', hwinfo: hwinfo, online_at: [1.day.ago.to_date.to_s << upd_online_hours, 1.day.ago.to_date.to_s << online_hours] } }

        it 'updates the uptime online_at_hours entry' do
          update_action
          expect(system.system_uptimes.count).to eq(1)
          expect(system_uptime.system_id).to eq(system.reload.id)
          expect(system_uptime.online_at_day.to_date).to eq(1.day.ago.to_date)
          expect(system_uptime.online_at_hours.to_s).to eq('111111111111111111111111')
        end
      end

      context 'when same uptime data duplicated' do
        let(:payload) { { hostname: 'test', hwinfo: hwinfo, online_at: [1.day.ago.to_date.to_s << online_hours, 1.day.ago.to_date.to_s << online_hours] } }

        it 'avoids duplication if multiple records have same data' do
          update_action

          expect(system.system_uptimes.count).to eq(1)
          expect(system_uptime.system_id).to eq(system.reload.id)
          expect(system_uptime.online_at_day.to_date).to eq(1.day.ago.to_date)
          expect(system_uptime.online_at_hours.to_s).to eq('111111111111111111111111')
        end
      end

      context 'when uptime data is malformed' do
        let(:payload) { { hostname: 'test', hwinfo: hwinfo, online_at: [1.day.ago.to_date.to_s] } }

        it 'record is not inserted' do
          update_action

          expect(system.system_uptimes.count).to eq(0)
        end
      end
    end

    context 'when hostname is not provided' do
      let(:payload) { { hwinfo: hwinfo } }

      it do
        update_action
        expect(system.reload.hostname).to be_nil
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
  end
end
