require 'rails_helper'

describe Api::Connect::V3::Subscriptions::SystemsController, type: :request do
  describe '#announce_system' do
    let(:instance_data) { '<instance_data/>' }
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
            cloud_provider: 'amazon'
          }
      }
    end
    let(:iid) do
      {
        accountId: '1234',
        architecture: 'some-arch',
        availabilityZone: 'some-zone',
        billingProducts: [ 'billing-info' ],
        devpayProductCodes: nil,
        marketplaceProductCodes: nil,
        imageId: 'ami-1234',
        instanceId: 'i-1234',
        instanceType: 'instance-type',
        kernelId: nil,
        pendingTime: 'yyyy-mm-ddThh:mm:ssZ',
        privateIp: 'some-ip',
        ramdiskId: nil,
        region: 'some-region',
        version: '2017-09-30'
      }.to_json
    end
    let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

    context 'using RMT generated credentials' do
      it 'saves instance data' do
        allow(InstanceVerification::Providers::Example).to receive(:new)
          .with(nil, nil, nil, instance_data).and_return(plugin_double)
        allow(plugin_double).to receive(:parse_instance_data).and_return(JSON.parse(iid))
        post '/connect/subscriptions/systems', params: params
        data = JSON.parse(response.body)
        system = System.find_by(login: data['login'])
        expect(system.instance_data).to eq(instance_data)
        expect(system.system_token).to eq('i-1234')
      end
    end
  end
end
