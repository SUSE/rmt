require 'rails_helper'

describe SccProxy do
  describe '.scc_host_base_url' do
    context 'when SCC_HOST is not set' do
      before { ENV.delete('SCC_HOST') }

      it 'uses the default SUSE cloud URL' do
        expect(described_class.scc_host_base_url).to eq('https://scc.suse.com/connect')
      end
    end

    context 'when SCC_HOST is set' do
      before { ENV['SCC_HOST'] = 'http://localhost:8080/connect' }

      it 'uses the configured host' do
        expect(described_class.scc_host_base_url).to eq('http://localhost:8080/connect')
      end
    end
  end

  describe '.announce_url' do
    before { ENV.delete('SCC_HOST') }

    it 'appends /subscriptions/systems to the base URL' do
      expect(described_class.announce_url).to eq('https://scc.suse.com/connect/subscriptions/systems')
    end
  end

  describe '.systems_products_url' do
    before { ENV.delete('SCC_HOST') }

    it 'appends /systems/products to the base URL' do
      expect(described_class.systems_products_url).to eq('https://scc.suse.com/connect/systems/products')
    end
  end

  describe '.systems_activations_url' do
    before { ENV.delete('SCC_HOST') }

    it 'appends /systems/activations to the base URL' do
      expect(described_class.systems_activations_url).to eq('https://scc.suse.com/connect/systems/activations')
    end
  end

  describe '.deregister_system_url' do
    before { ENV.delete('SCC_HOST') }

    it 'appends /systems to the base URL' do
      expect(described_class.deregister_system_url).to eq('https://scc.suse.com/connect/systems')
    end
  end

  describe '.parse_url' do
    let(:url) { 'https://scc.suse.com/connect/systems/products' }

    it 'returns a URI and a configured Net::HTTP' do
      uri, http = described_class.parse_url(url)
      expect(uri).to be_a(URI::HTTPS)
      expect(http).to be_a(Net::HTTP)
      expect(http.use_ssl?).to be true
    end

    context 'with http URL' do
      let(:url) { 'http://localhost:8080/connect/systems/products' }

      it 'returns a URI and a configured Net::HTTP' do
        uri, http = described_class.parse_url(url)
        expect(uri).to be_a(URI::HTTP)
        expect(http).to be_a(Net::HTTP)
        expect(http.use_ssl?).to be false
      end
    end
  end
end
