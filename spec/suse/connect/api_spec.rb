require 'rails_helper'
require 'webmock/rspec'

RSpec.describe SUSE::Connect::Api do
  before do
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
  let(:username) { 'scc_user' }
  let(:password) { 'scc_password' }
  let(:api_client) { described_class.new(username, password) }
  let(:expected_request_headers) do
    {
      'Authorization' => 'Basic ' + Base64.encode64("#{username}:#{password}").strip,
      'User-Agent' => "RMT/#{RMT::VERSION}"
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

  describe '#list_repositories' do
    subject { api_client.list_repositories }

    it { is_expected.to eq([ { endpoint: 'organizations/repositories' } ]) }
  end

  describe '#list_subscriptions' do
    subject { api_client.list_subscriptions }

    it { is_expected.to eq([ { endpoint: 'organizations/subscriptions' } ]) }
  end
end
