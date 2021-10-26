require 'rails_helper'

describe Api::Connect::V3::Subscriptions::SystemsController, type: :request do
  describe '#announce_system' do
    let(:instance_data) { '<instance_data/>' }

    context 'using RMT generated credentials' do
      it 'saves instance data' do
        post '/connect/subscriptions/systems', params: { hostname: 'test', instance_data: instance_data }
        data = JSON.parse(response.body)
        system = System.find_by(login: data['login'])
        expect(system.hw_info.instance_data).to eq(instance_data)
      end
    end

    context 'registering the system with SCC' do
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
        before do
          stub_request(:post, scc_register_system_url)
            .to_return(
              status: 201,
              body: scc_register_response.to_s,
              headers: {}
            )
        end

        it 'saves the data' do
          post '/connect/subscriptions/systems', params: params, headers: { HTTP_AUTHORIZATION: 'Token token=bar' }
          system = System.find_by(login: 'SCC_foo')
          expect(system.hw_info.instance_data).to eq(instance_data)
        end
      end

      context 'credentials not found' do
        before do
          stub_request(:post, scc_register_system_url)
            .to_return(
              status: 401,
              body: scc_register_response.to_s,
              headers: {}
            )
        end

        it 'returns error' do
          post '/connect/subscriptions/systems', params: params, headers: { HTTP_AUTHORIZATION: 'Token token=bar' }
          data = JSON.parse(response.body)
          expect(data['type']).to eq('error')
          expect(data['error']).to eq('No subscription with this Registration Code found')
        end
      end

      context 'unreachable server' do
        before do
          stub_request(:post, scc_register_system_url)
            .to_return(
              status: 408,
              body: scc_register_response.to_s,
              headers: {}
            )
        end

        it 'returns error' do
          post '/connect/subscriptions/systems', params: params, headers: { HTTP_AUTHORIZATION: 'Token token=bar' }
          data = JSON.parse(response.body)
          expect(data['type']).to eq('error')
          expect(data['error']).to eq('408 ""')
        end
      end
    end
  end
end
