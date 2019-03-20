require 'rails_helper'
require 'webmock/rspec'
require 'registration_sharing/client'

describe RegistrationSharing::Client do
  let(:peer) { 'example.org' }
  let(:api_secret) { 's3cr3tt0k3n' }
  let(:expected_headers) do
    {
      'Authorization' => "Bearer #{api_secret}",
      'Content-Type' => 'application/json',
      'Expect' => '',
      'User-Agent' => "RMT::Regsharing/#{RMT::VERSION}"
    }
  end

  before do
    allow(Settings).to receive(:[]).with(:regsharing).and_return({ api_secret: api_secret })
  end

  describe '#peer_register_system' do
    let(:client) { described_class.new(peer, system.login) }
    let(:system) do
      FactoryGirl.create(
        :system, :with_activated_product,
        :with_hw_info, instance_data: instance_data
      )
    end
    let(:instance_data) { '<document>test</document>' }
    let(:expected_payload) do
      {
        'login' => system.login,
        'password' => system.password,
        'hostname' => system.hostname,
        'registered_at' => system.registered_at,
        'created_at' => system.created_at,
        'last_seen_at' => nil,
        'activations' => [
          { 'product_id' => system.products.first.id, 'created_at' => system.activations.first.created_at }
        ],
        'instance_data' => instance_data
      }
    end

    context 'when request fails' do
      it 'raises an exception' do
        stub_request(:post, "https://#{peer}/api/regsharing")
          .with(
            body: JSON.dump(expected_payload),
            headers: expected_headers
          ).to_return(status: 422, body: '', headers: {})

        expect { client.sync_system }.to raise_error(/Regsharing request failed/)
      end
    end

    context 'when request succeeds' do
      it 'returns the response' do
        stub_request(:post, "https://#{peer}/api/regsharing")
          .with(
            body: JSON.dump(expected_payload),
            headers: expected_headers
          ).to_return(status: 204, body: '', headers: {})

        expect(client.sync_system).to be_a(Typhoeus::Response)
      end
    end
  end

  describe '#peer_deregister_system' do
    let(:nonexistent_login) { 'removedsystemlogin' }
    let(:client) { described_class.new(peer, nonexistent_login) }
    let(:expected_payload) { { 'login' => nonexistent_login } }

    context 'when request fails' do
      it 'raises an exception' do
        stub_request(:delete, "https://#{peer}/api/regsharing")
          .with(
            body: JSON.dump(expected_payload),
            headers: expected_headers
          ).to_return(status: 422, body: '', headers: {})

        expect { client.sync_system }.to raise_error(/Regsharing request failed/)
      end
    end

    context 'when request succeeds' do
      it 'returns the response' do
        stub_request(:delete, "https://#{peer}/api/regsharing")
          .with(
            body: JSON.dump(expected_payload),
            headers: expected_headers
          ).to_return(status: 204, body: '', headers: {})

        expect(client.sync_system).to be_a(Typhoeus::Response)
      end
    end
  end
end
