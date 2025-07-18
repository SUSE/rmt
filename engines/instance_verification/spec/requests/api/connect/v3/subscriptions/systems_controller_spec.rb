require 'rails_helper'

describe Api::Connect::V3::Subscriptions::SystemsController, type: :request do
  describe '#announce_system' do
    let(:instance_data) { '<instance_data/>' }

    context 'using RMT generated credentials' do
      it 'saves instance data' do
        post '/connect/subscriptions/systems', params: { hostname: 'test', instance_data: instance_data }
        data = JSON.parse(response.body)
        system = System.find_by(login: data['login'])
        expect(system.instance_data).to eq(instance_data)
        expect(system.login).to start_with('SCC_')
      end
    end

    context 'using instance id' do
      it 'saves instance data' do
        allow_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_identifier).and_return('i-12345')
        post '/connect/subscriptions/systems', params: { hostname: 'test', instance_data: instance_data }
        data = JSON.parse(response.body)
        system = System.find_by(login: data['login'])
        expect(system.instance_data).to eq(instance_data)
        expect(system.login).to start_with('i-')
      end
    end
  end
end
