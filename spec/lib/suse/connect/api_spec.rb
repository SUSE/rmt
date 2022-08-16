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
        allow(File).to receive(:read).with(described_class::UUID_FILE_LOCATION).and_return(uuid)
        expect(method_call).to be(uuid)
      end
    end

    context 'when system_uuid file does not exist' do
      it 'creates a file' do
        allow(File).to receive(:exist?).with(described_class::UUID_FILE_LOCATION).and_return(false)
        allow(SecureRandom).to receive(:uuid).and_return(uuid)

        allow(File).to receive(:write).with(described_class::UUID_FILE_LOCATION, uuid).once
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
        expect(File).to receive(:write).with(described_class::UUID_FILE_LOCATION, uuid).once
        expect(method_call).to be(uuid)
      end
    end
  end

  # rubocop:disable RSpec/MessageChain
  describe '#connect_api' do
    subject(:method_call) { api_client.send(:connect_api) }

    context 'with valid uris given' do
      %w[
        https://scc.suse.com/connect
        http://localhost:3000/connect
        http://192.168.1.3:3000/connect
      ].each do |uri|
        it 'returns a validated url' do
          allow(Settings).to receive_message_chain(:scc, :host).and_return(uri)
          expect(method_call).to be(uri)
        end
      end
    end

    context 'with an invalid/malformed uri given' do
      %w[
        localhst:3000/connect
        ftp://192.168.1.3:3000/connect
        htts://scc.suse.com/connect
        htxxtp://xxxxxxlocalhost:3000
      ].each do |uri|
        it 'raises an exception' do
          allow(Settings).to receive_message_chain(:scc, :host).and_return(uri)
          exception_msg = "Encountered an error validating #{uri}. Be sure to add http/https if it's an absolute url, i.e IP Address"
          expect_any_instance_of(RMT::Logger).to receive(:error).with(exception_msg)
          expect { method_call }.to raise_exception(SystemExit)
        end
      end
    end
  end
  # rubocop:enable RSpec/MessageChain

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
        'RMT' => uuid,
        'HOST-SYSTEM' => '',
        'Accept' => 'application/vnd.scc.suse.com.v4+json'
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

    describe '#send_bulk_system_update' do
      let(:expected_request_headers) do
        {
          'Authorization' => 'Basic ' + Base64.encode64("#{username}:#{password}").strip,
          'User-Agent' => "RMT/#{RMT::VERSION}",
          'RMT' => uuid,
          'HOST-SYSTEM' => '',
          'Accept' => 'application/vnd.scc.suse.com.v4+json'
        }
      end

      let(:systems) { [] }

      let(:system_keys) { %i[id login password last_seen_at] }
      let(:product_keys) { %i[id identifier version arch] }
      let(:hwinfo_keys) { %i[cpus sockets hypervisor arch uuid cloud_provider] }

      let(:expected_body) { { systems: [] } }

      let(:expected_response) do
        system_hashes = systems.collect do |s|
          s.slice(*system_keys).symbolize_keys
        end
        { systems: system_hashes }
      end

      before do
        stub_request(:put, 'https://scc.suse.com/connect/organizations/systems')
          .with(
            headers: expected_request_headers,
            body: expected_body.to_json
          )
          .to_return(
            status: 201,
            body: expected_response.to_json,
            headers: {}
          )
      end

      context 'when a single system is bulk updated' do
        let(:systems) { create_list :system, 1, :full }
        let(:product) { system.products.first }
        let(:hw_info) { system.hw_info }

        let(:expected_body) do
          system_hashes = systems.collect do |system|
            product = system.products.first.slice(*product_keys)
            hwinfo = system.hw_info.slice(*hwinfo_keys)
            {
              login: system.login,
              password: system.password,
              last_seen_at: system.last_seen_at,
              hostname: system.hostname,
              hwinfo: hwinfo,
              products: [product]
            }
          end.compact
          { systems: system_hashes }
        end

        it 'yields results' do
          expect do |block|
            relation = System.where(id: systems.pluck(:id))
            api_client.send_bulk_system_update(relation, &block)
          end.to yield_with_args(expected_response)
        end
      end

      context 'when sending in bulk' do
        let(:systems) { create_list :system, 3, :full, scc_synced_at: nil }
        let(:product) { system.products.first }
        let(:hw_info) { system.hw_info }

        let(:expected_body) do
          system_hashes = systems.collect do |system|
            product = system.products.first.slice(*product_keys)
            hwinfo = system.hw_info.slice(*hwinfo_keys)
            {
              login: system.login,
              password: system.password,
              last_seen_at: system.last_seen_at,
              hostname: system.hostname,
              hwinfo: hwinfo,
              products: [product]
            }
          end.compact
          { systems: system_hashes }
        end

        it 'yields successful results' do
          expect do |block|
            relation = System.where(id: systems.pluck(:id))
            api_client.send_bulk_system_update(relation, &block)
          end.to yield_with_args(expected_response)
        end
      end

      context 'when sending in bulk with and without system_token' do
        let!(:system1) { create :system, :full, :with_system_token, :synced }
        let!(:system2) { create :system, :full, :synced }

        let(:systems) { [system1, system2] }

        let(:expected_body) do
          {
            systems: [
              {
                login: system1.login,
                password: system1.password,
                last_seen_at: system1.last_seen_at,
                system_token: system1.id
              },
              {
                login: system2.login,
                password: system2.password,
                last_seen_at: system2.last_seen_at
              }
            ]
          }
        end

        it 'yields successful results' do
          expect do |block|
            relation = System.where(id: systems.pluck(:id))
            api_client.send_bulk_system_update(relation, &block)
          end.to yield_with_args(expected_response)
        end
      end

      context 'when sending in bulk and encounter 413 http error code' do
        before do
          stub_request(:put, 'https://scc.suse.com/connect/organizations/systems')
            .with(
              headers: expected_request_headers,
              body: all_systems_payload.to_json
            )
            .to_return(
              status: 413,
              headers: {
                'X-Payload-Entities-Max-Limit': 1
              },
              body: [].to_json
            )
          stub_request(:put, 'https://scc.suse.com/connect/organizations/systems')
            .with(
              headers: expected_request_headers
            )
            .to_return(
              status: 201,
              body: expected_response.to_json,
              headers: {}
            )
        end

        let(:subscription) { create :subscription }
        let(:systems) { create_list(:system, 2, :full, subscription: subscription, scc_synced_at: nil) }

        let(:expected_response) { { systems: [systems.last.slice(*system_keys).symbolize_keys] } }

        let(:all_systems_payload) do
          system_hashes = systems.collect do |system|
            product = system.products.first.slice(*product_keys)
            product[:regcode] = subscription.regcode

            hwinfo = system.hw_info.slice(*hwinfo_keys)
            {
              login: system.login,
              password: system.password,
              last_seen_at: system.last_seen_at,
              hostname: system.hostname,
              hwinfo: hwinfo,
              products: [product]
            }
          end.compact
          { systems: system_hashes }
        end

        let(:expected_body) do
          system_hashes = systems.take(1).collect do |system|
            product = system.products.first.slice(*product_keys)
            product[:regcode] = subscription.regcode

            hwinfo = system.hw_info.slice(*hwinfo_keys)
            {
              login: system.login,
              password: system.password,
              last_seen_at: system.last_seen_at,
              hostname: system.hostname,
              hwinfo: hwinfo,
              products: [product]
            }
          end.compact
          { systems: system_hashes }
        end

        it 'yields successful results' do
          expect do |block|
            relation = System.where(id: systems.pluck(:id))
            api_client.send_bulk_system_update(relation, &block)
          end.to yield_with_args(expected_response)
        end
      end

      context 'when sending in bulk and a system which only sends last_seen_at' do
        let(:system_set) { create :system, :synced }
        let(:systems_unset) { create_list :system, 2, :full }

        let(:systems) { [system_set] + systems_unset }

        let(:expected_body_set) do
          {
            login: system_set.login,
            password: system_set.password,
            last_seen_at: system_set.last_seen_at
          }
        end
        let(:expected_body_unset) do
          systems_unset.collect do |system|
            product = system.products.first.slice(*product_keys)
            hwinfo = system.hw_info.slice(*hwinfo_keys)
            {
              login: system.login,
              password: system.password,
              last_seen_at: system.last_seen_at,
              hostname: system.hostname,
              hwinfo: hwinfo,
              products: [product]
            }
          end
        end
        let(:expected_body) { { systems: [expected_body_set] + expected_body_unset } }

        it 'yields successful results' do
          expect do |block|
            relation = System.where(id: systems.pluck(:id))
            api_client.send_bulk_system_update(relation, &block)
          end.to yield_with_args(expected_response)
        end
      end
    end

    describe '#forward_system_deregistration' do
      before do
        stub_request(:delete, "https://scc.suse.com/connect/organizations/systems/#{scc_system_id}")
          .with(
            headers: expected_request_headers,
            body: ''
          )
          .to_return(
            status: expected_status,
            body: ''
          )
      end

      let(:scc_system_id) { 9000 }

      context 'when system is found on SCC' do
        let(:expected_status) { 204 }

        it "doesn't raise errors" do
          expect { api_client.forward_system_deregistration(scc_system_id) }.not_to raise_error
        end
      end

      context 'when system is not found on SCC' do
        let(:expected_status) { 404 }

        it "doesn't raise errors" do
          expect { api_client.forward_system_deregistration(scc_system_id) }.not_to raise_error
        end
      end
    end
  end


  describe '.make_request' do
    let(:url) { 'http://example.com' }
    let(:expected_request_headers) do
      {
        'Authorization' => 'Basic ' + Base64.encode64("#{username}:#{password}").strip,
        'User-Agent' => "RMT/#{RMT::VERSION}",
        'HOST-SYSTEM' => '',
        'RMT' => uuid
      }
    end

    context 'on successful request' do
      subject { api_client.send(:make_request, 'GET', 'http://example.org/api_method', {}) }

      before do
        allow_any_instance_of(described_class).to receive(:system_uuid).and_return(uuid)

        stub_request(:GET, 'http://example.org/api_method')
          .to_return(
            status: 200,
            body: response_data,
            headers: {}
          )
      end

      let(:response_data) { "Everything's great!" }

      it { is_expected.to be_a(Typhoeus::Response) }
      its(:body) { is_expected.to eq(response_data) }
    end

    context 'on error' do
      subject(:api_request) { api_client.send(:make_request, 'GET', 'http://example.org/api_method', {}) }

      before do
        allow_any_instance_of(described_class).to receive(:system_uuid).and_return(uuid)

        stub_request(:GET, 'http://example.org/api_method')
          .to_return(
            status: 503,
            body: response_data,
            headers: {}
          )
      end

      let(:response_data) { 'Something went terribly wrong!' }

      it 'raises APIRequestError' do
        expect { api_request }.to raise_error(
          an_instance_of(SUSE::Connect::Api::RequestError).and(
            having_attributes(
              response: an_instance_of(Typhoeus::Response).and(
                having_attributes(body: response_data)
              )
            )
          )
        )
      end
    end
  end
end
