require 'rails_helper'
require 'webmock/rspec'
require 'fakefs/spec_helpers'

RSpec.describe SUSE::Connect::Api do
  let(:username) { 'scc_user' }
  let(:password) { 'scc_password' }
  let(:api_client) { described_class.new(username, password) }
  let(:uuid) { 'test-uuid' }

  describe '#system_uuid' do
    subject(:method_call) { api_client.send(:system_uuid) }

    context 'when system_uuid file exists' do
      it 'reads a file' do
        allow(File).to receive(:exist?).with(described_class::UUID_FILE_LOCATION).and_return(true)
        expect(File).not_to receive(:write).with(described_class::UUID_FILE_LOCATION, uuid)
        expect(File).to receive(:read).with(described_class::UUID_FILE_LOCATION).and_return(uuid)
        expect(method_call).to be(uuid)
      end
    end

    context 'when system_uuid file does not exist' do
      it 'creates a file' do
        allow(File).to receive(:exist?).with(described_class::UUID_FILE_LOCATION).and_return(false)
        allow(SecureRandom).to receive(:uuid).and_return(uuid)

        expect(File).to receive(:write).with(described_class::UUID_FILE_LOCATION, uuid).exactly(1).times
        expect(File).not_to receive(:read).with(described_class::UUID_FILE_LOCATION)
        expect(method_call).to be(uuid)
      end
    end

    context 'when system_uuid file is empty' do
      before do
          allow(File).to receive(:exist?).with(described_class::UUID_FILE_LOCATION).and_return(true)
          allow(File).to receive(:empty?).with(described_class::UUID_FILE_LOCATION).and_return(true)
          allow(SecureRandom).to receive(:uuid).and_return(uuid)
      end

      it 'overwrites a file' do
        expect(File).to receive(:write).with(described_class::UUID_FILE_LOCATION, uuid).exactly(1).times
        expect(method_call).to be(uuid)
      end
    end   
  end

  context 'api requests' do
    before do
      allow_any_instance_of(described_class).to receive(:system_uuid).and_return(uuid)

      stub_request(:GET, 'http://example.org/api_method')
        .with(headers: expected_request_headers)
        .to_return(
          status: 200,
          body: response_data.to_json,
          headers: {}
        )

      stub_request(:GET, 'http://example.org/api_method?page=1')
        .with(headers: expected_request_headers)
        .to_return(
          status: 200,
          body: [ response_data ].to_json,
          headers: {
            'Link' => '<http://example.org/api_method?page=2>; rel="next"'
          }
        )

      stub_request(:GET, 'http://example.org/api_method?page=2')
        .with(headers: expected_request_headers)
        .to_return(
          status: 200,
          body: [ response_data ].to_json,
          headers: {}
        )

      stub_request(:get, 'https://scc.suse.com/connect/organizations/orders?page=1')
        .with(headers: expected_request_headers)
        .to_return(
          status: 200,
          body: [ { endpoint: 'organizations/orders' } ].to_json,
          headers: {}
        )

      stub_request(:get, 'https://scc.suse.com/connect/organizations/products?page=1')
        .with(headers: expected_request_headers)
        .to_return(
          status: 200,
          body: [ { endpoint: 'organizations/products' } ].to_json,
          headers: {}
        )

      stub_request(:get, 'https://scc.suse.com/connect/organizations/products/unscoped?page=1')
        .with(headers: expected_request_headers)
        .to_return(
          status: 200,
          body: [ { endpoint: 'organizations/products/unscoped' } ].to_json,
          headers: {}
        )

      stub_request(:get, 'https://scc.suse.com/connect/organizations/repositories?page=1')
        .with(headers: expected_request_headers)
        .to_return(
          status: 200,
          body: [ { endpoint: 'organizations/repositories' } ].to_json,
          headers: {}
        )

      stub_request(:get, 'https://scc.suse.com/connect/organizations/subscriptions?page=1')
        .with(headers: expected_request_headers)
        .to_return(
          status: 200,
          body: [ { endpoint: 'organizations/subscriptions' } ].to_json,
          headers: {}
        )
    end

    let(:url) { 'http://example.com' }
    let(:expected_request_headers) do
      {
        'Authorization' => 'Basic ' + Base64.encode64("#{username}:#{password}").strip,
        'User-Agent' => "RMT/#{RMT::VERSION}",
        'RMT' => uuid
      }
    end
    let(:response_data) { { foo: 'bar' } }

    describe '#make_single_request' do
      subject { api_client.send(:make_single_request, 'GET', 'http://example.org/api_method') }

      it { is_expected.to eq(response_data) }
    end

    describe '#make_paginated_request' do
      subject { api_client.send(:make_paginated_request, 'GET', 'http://example.org/api_method') }

      it { is_expected.to eq([response_data, response_data]) }
    end

    describe '#list_orders' do
      subject { api_client.list_orders }

      it { is_expected.to eq([ { endpoint: 'organizations/orders' } ]) }
    end

    describe '#list_products' do
      subject { api_client.list_products }

      it { is_expected.to eq([ { endpoint: 'organizations/products' } ]) }
    end

    describe '#list_products_unscoped' do
      subject { api_client.list_products_unscoped }

      it { is_expected.to eq([ { endpoint: 'organizations/products/unscoped' } ]) }
    end

    describe '#list_repositories' do
      subject { api_client.list_repositories }

      it { is_expected.to eq([ { endpoint: 'organizations/repositories' } ]) }
    end

    describe '#list_subscriptions' do
      subject { api_client.list_subscriptions }

      it { is_expected.to eq([ { endpoint: 'organizations/subscriptions' } ]) }
    end
  end
end
