require 'rails_helper'

RSpec.describe Api::Connect::V3::Subscriptions::SystemsController do
  describe '#announce' do
    include_context 'version header', 3
    let(:url) { connect_systems_url(format: :json) }
    let(:headers) { { 'Content-Type' => 'application/json; charset=utf-8' }.merge(version_header) }

    context 'when there are no additional parameters' do
      before { post url }
      subject { response }

      it { is_expected.to be_success }

      describe 'JSON response' do
        subject { json_response }

        its([:login]) { is_expected.to start_with 'SCC_' }
        its(:keys) { is_expected.to include :password }
      end
    end

    context 'when there are additional parameters' do
      before { post url, params: { payload: { hostname: 'testhost' } }.to_json, headers: headers }
      subject { response }

      it { is_expected.to be_success }
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
      subject { response }

      let(:hwinfo) { { cpus: 8, sockets: 1, arch: 'x86_64' } }

      before do
        post url, params: { hwinfo: hwinfo }.to_json, headers: headers
      end

      it { is_expected.to be_success }
      its(:status) { is_expected.to eq 201 }

      describe 'stored hwinfo' do
        subject { System.find_by(login: json_response[:login]).hw_info }

        its(:cpus) { is_expected.to eql hwinfo[:cpus] }
        its(:sockets) { is_expected.to eql hwinfo[:sockets] }
        its(:arch) { is_expected.to eql hwinfo[:arch] }
      end
    end

    context 'uuid processing' do
      subject { System.find_by(login: json_response[:login]).hw_info }

      before do
        post url, params: { hwinfo: hwinfo }.to_json, headers: headers
      end

      context 'with valid uuid' do
        let(:hwinfo) { { cpus: 8, sockets: 1, arch: 'x86_64', hypervisor: 'XEN', uuid: 'f46906c5-d87d-4e4c-894b-851e80376003' } }

        its(:uuid) { is_expected.to eql 'f46906c5-d87d-4e4c-894b-851e80376003' }
      end

      context 'with invalid uuid' do
        let(:hwinfo) { { cpus: 8, sockets: 1, arch: 'x86_64', uuid: '123' } }

        it { is_expected.not_to be nil }
        its(:uuid) { is_expected.to be nil }
      end

      context 'with nil uuid' do
        let(:hwinfo) { { cpus: 8, sockets: 1, arch: 'x86_64', hypervisor: 'XEN', uuid: nil } }

        it { is_expected.not_to be nil }
        its(:uuid) { is_expected.to be nil }
      end
    end
  end
end
