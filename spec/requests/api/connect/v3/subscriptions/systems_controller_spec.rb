require 'rails_helper'

RSpec.describe Api::Connect::V3::Subscriptions::SystemsController do
  describe '#announce' do
    include_context 'version header', 3
    let(:url) { connect_systems_url(format: :json) }
    let(:headers) { { 'Content-Type' => 'application/json; charset=utf-8' }.merge(version_header) }

    context 'when there are no additional parameters' do
      before { post url }
      subject { response }

      it { is_expected.to be_successful }

      describe 'JSON response' do
        subject { json_response }

        its([:login]) { is_expected.to start_with 'SCC_' }
        its(:keys) { is_expected.to include :password }
      end
    end

    context 'when there are additional parameters' do
      before { post url, params: { payload: { hostname: 'testhost' } }.to_json, headers: headers }
      subject { response }

      it { is_expected.to be_successful }
      its(:status) { is_expected.to eq 201 }

      describe 'JSON response' do
        subject { json_response }

        its([:login]) { is_expected.to start_with 'SCC_' }
        its(:keys) { is_expected.to include :password }
      end
    end

    context 'when multiple systems are announced' do
      before do
        System.delete_all # to remove excessive systems created by factories

        3.times do |i|
          post url, params: { hostname: "testhost#{i}" }.to_json, headers: headers
        end
      end

      subject { System }

      its(:count) { is_expected.to eq(3) }

      describe 'hostnames' do
        subject { System.pluck(:hostname) }

        it { is_expected.to match_array(%w[testhost0 testhost1 testhost2]) }
      end
    end

    context 'with hwinfo parameters' do
      let(:hwinfo_parameter) do
        {
          cpus: 8,
          sockets: 1,
          arch: 'x86_64',
          hypervisor: 'XEN',
          uuid: 'f46906c5-d87d-4e4c-894b-851e80376003',
          cloud_provider: 'cloud'
        }
      end

      it 'stores the hwinfo parameters as system information' do
        post url, params: { hwinfo: hwinfo_parameter }.to_json, headers: headers

        expect(response).to be_successful
        expect(response).to have_http_status(:created)

        system = System.find_by(login: json_response[:login])

        expect(system.system_information).to eq(hwinfo_parameter.to_json)
      end
    end
  end
end
