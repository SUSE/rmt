require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
describe Api::Connect::V3::Subscriptions::SystemsController, type: :request do
  describe '#announce_system' do
    let(:instance_data) { '<instance_data/>' }

    context 'using SCC generated credentials (BYOS mode)' do
      let(:scc_register_system_url) { 'https://scc.suse.com/connect/subscriptions/systems' }
      let(:scc_register_response) do
        {
          id: 5684096,
          login: 'SCC_foo',
          password: '1234',
          last_seen_at: '2021-10-24T09:48:52.658Z'
        }.to_json
      end
      let(:params) do
        {
          hostname: 'test',
          proxy_byos_mode: :payg,
          instance_data: instance_data,
          hwinfo:
            {
              hostname: 'test',
              cpus: '1',
              sockets: '1',
              hypervisor: 'Xen',
              arch: 'x86_64',
              uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
              cloud_provider: 'super_cloud'
            }
        }
      end

      context 'valid credentials' do
        let(:plugin_double) { instance_double('DataExport::Handlers::Example') }

        before do
          allow(DataExport::Handlers::Example).to receive(:new).and_return(plugin_double)
          allow(plugin_double).to receive(:update_info)
          stub_request(:post, scc_register_system_url)
            .to_return(
              status: 201,
              body: scc_register_response.to_s,
              headers: {}
            )
        end

        it 'saves the data' do
          expect(plugin_double).to receive(:update_info)
          post '/connect/subscriptions/systems', params: params, headers: { HTTP_AUTHORIZATION: 'Token token=' }
        end

        context 'export fails' do
          let(:logger) { instance_double('RMT::Logger').as_null_object }

          before do
            allow(DataExport::Handlers::Example).to receive(:new).and_return(plugin_double)
            allow(plugin_double).to receive(:update_info).and_raise('foo')
            allow(Rails.logger).to receive(:error)
            stub_request(:post, scc_register_system_url)
              .to_return(
                status: 201,
                body: scc_register_response.to_s,
                headers: {}
            )
          end

          it 'does not save the data and log error' do
            expect(plugin_double).to receive(:update_info)
            expect(Rails.logger).to receive(:error)
            post '/connect/subscriptions/systems', params: params, headers: { HTTP_AUTHORIZATION: 'Token token=' }
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
