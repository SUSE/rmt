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

    context 'with hw_info' do
      let(:hw_info) { { cpus: 8, sockets: 1, arch: 'x86_64', hypervisor: 'XEN', uuid: uuid } }
      let(:uuid) { 'f46906c5-d87d-4e4c-894b-851e80376003' }

      before do
        post url, params: { hwinfo: hw_info }.to_json, headers: headers
      end

      context 'with hw_info parameters' do
        subject { response }

        it { is_expected.to be_success }
        its(:status) { is_expected.to eq 201 }

        describe 'stored hw_info' do
          subject { System.find_by(login: json_response[:login]).hw_info }

          its(:cpus) { is_expected.to eql hw_info[:cpus] }
          its(:sockets) { is_expected.to eql hw_info[:sockets] }
          its(:arch) { is_expected.to eql hw_info[:arch] }
        end
      end

      context 'uuid processing' do
        subject { System.find_by(login: json_response[:login]).hw_info }

        context 'with valid uuid' do
          its(:uuid) { is_expected.to eql 'f46906c5-d87d-4e4c-894b-851e80376003' }
        end

        context 'with invalid uuid' do
          let(:uuid) { '123' }

          it { is_expected.not_to be nil }
          its(:uuid) { is_expected.to be nil }
        end

        context 'with nil uuid' do
          let(:uuid) { nil }

          it { is_expected.not_to be nil }
          its(:uuid) { is_expected.to be nil }
        end
      end
    end
  end
end
