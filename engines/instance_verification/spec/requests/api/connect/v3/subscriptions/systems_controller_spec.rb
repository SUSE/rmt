require 'rails_helper'

describe Api::Connect::V3::Subscriptions::SystemsController, type: :request do
  describe '#announce_system' do
    let(:instance_data) { '<instance_data/>' }

    it 'saves instance data' do
      post '/connect/subscriptions/systems', params: { hostname: 'test', instance_data: instance_data }
      data = JSON.parse(response.body)
      system = System.find_by(login: data['login'])
      expect(system.hw_info.instance_data).to eq(instance_data)
    end
  end
end
