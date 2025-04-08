require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3
  include_context 'user-agent header'
  include_context 'zypp user-agent header'

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
  let(:plugin_double) { instance_double('DataExport::Handlers::Example') }

  describe '#update' do
    subject(:update_action) { put url, params: payload, headers: headers }

    context 'when update success' do
      before { allow(DataExport::Handlers::Example).to receive(:new).and_return(plugin_double) }

      context 'when data export success' do
        before { allow(plugin_double).to receive(:export_rmt_data) }

        it do
          expect(plugin_double).to receive(:export_rmt_data)
          expect { update_action }.to change { system.reload.hostname }.from('initial').to(payload[:hostname])
        end
      end

      context 'when data export fails' do
        before do
          allow(plugin_double).to receive(:export_rmt_data).and_raise('foo')
          allow(Rails.logger).to receive(:error)
        end

        it do
          expect(plugin_double).to receive(:export_rmt_data)
          expect(Rails.logger).to receive(:error)
          update_action
        end
      end
    end
  end

  describe 'db check' do
    # this test needs to be updated if the system table change structure
    # the reason is that if this check fails => the engine data_export could not
    # send data to the Data Warehouse telemetry, that CAN NOT happen
    # if this test fails, the implementation of the call `data_export_handler.export_rmt_data`
    # invoked in engines/data_export/lib/data_export/engine.rb needs to change accordingly
    before do
      FactoryBot.create(:system, :with_system_information, hostname: 'initial')
    end

    context 'when the db changes' do
      let(:columns) { System.column_names }
      let(:expected_columns) do
        [
          'id',
          'login',
          'password',
          'hostname',
          'registered_at',
          'last_seen_at',
          'created_at',
          'updated_at',
          'scc_registered_at',
          'scc_system_id',
          'proxy_byos',
          'system_token',
          'system_information',
          'instance_data',
          'proxy_byos_mode',
          'pubcloud_reg_code'
        ]
      end
      let(:check_system) { System.all.first }

      it 'raises an error' do
        expect(columns).to eq(expected_columns)
        expect(JSON.parse(check_system.system_information)['cpus']).to eq(2)
        expect(JSON.parse(check_system.system_information)['arch']).to eq('x86_64')
        expect(JSON.parse(check_system.system_information)['mem_total']).to eq(64)
        expect(JSON.parse(check_system.system_information)['cloud_provider']).to eq('Amazon')
      end
    end
  end
end
