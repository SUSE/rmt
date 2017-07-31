require 'rails_helper'

RSpec.describe RMT::HttpRequest do
  let!(:options) do
    options = {
      verbose: true,
      proxy: 'http://localhost:3128',
      proxy_auth: :ntlm,
      proxy_user: 'login',
      proxy_password: 'password'
    }
    options.each { |key, value| Settings.http_client.send("#{key}=", value) }
    options
  end
  let(:request) { described_class.new('http://example.com') }

  describe 'request options' do
    subject { request.options }

    its([:verbose]) { is_expected.to eq(options[:verbose]) }
    its([:proxy]) { is_expected.to eq(options[:proxy]) }
    its([:proxyauth]) { is_expected.to eq(options[:proxy_auth]) }
    its([:proxyuserpwd]) { is_expected.to eq("#{options[:proxy_user]}:#{options[:proxy_password]}") }

    it 'has correct User-Agent' do
      expect(request.options[:headers]['User-Agent']).to eq("RMT/#{RMT::VERSION}")
    end
  end
end
