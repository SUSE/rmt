require 'rails_helper'
require 'webrick'

RSpec.describe RMT::HttpRequest do
  describe 'request options' do
    subject { request.options }

    let!(:options) do
      options = {
        verbose: true,
        proxy: 'http://localhost:3128',
        proxy_auth: :ntlm,
        proxy_user: 'login',
        proxy_password: 'password',
        low_speed_limit: 1337,
        low_speed_time: 42
      }
      options.each { |key, value| Settings.http_client.send("#{key}=", value) }
      options
    end
    let(:request) { described_class.new('http://example.com') }

    its([:verbose]) { is_expected.to eq(options[:verbose]) }
    its([:proxy]) { is_expected.to eq(options[:proxy]) }
    its([:proxyauth]) { is_expected.to eq(options[:proxy_auth]) }
    its([:proxyuserpwd]) { is_expected.to eq("#{options[:proxy_user]}:#{options[:proxy_password]}") }

    it 'has correct User-Agent' do
      expect(request.options[:headers]['User-Agent']).to eq("RMT/#{RMT::VERSION}")
    end

    its([:low_speed_limit]) { is_expected.to eq(1337) }
    its([:low_speed_time]) { is_expected.to eq(42) }
  end

  describe 'when request is too slow' do
    let(:port) { 55555 }
    let(:server_thread) do
      Thread.new do
        dev_null = WEBrick::Log.new('/dev/null', 7)

        Rack::Server.start(
          app: lambda do |_|
            sleep 5
            [200, { 'Content-Type' => 'text/html' }, ['hello world']]
          end,
          server: 'webrick',
          Logger: dev_null,
          AccessLog: dev_null,
          Port: port
        )
      end
    end
    let(:request) do
      request = described_class.new("http://localhost:#{port}/")
      request.options[:low_speed_time] = 2
      request
    end

    around do |example|
      Settings.reload!
      server_thread.wakeup
      sleep 1 # for server to start up
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
      server_thread.kill
    end

    it 'returns with :operation_timedout' do
      response = request.run
      expect(response.return_code).to eq(:operation_timedout)
    end
  end
end
