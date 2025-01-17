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
end
