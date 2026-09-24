require 'rails_helper'

describe SccProxy do
  describe 'SCC_BASE_URL' do
    it 'uses the default SUSE cloud URL when SCC_HOST env var is not set' do
      expect(SccProxy.singleton_class::SCC_BASE_URL).to eq('https://scc.suse.com/connect')
    end
  end

  describe 'ANNOUNCE_URL' do
    it 'appends /subscriptions/systems to the base URL' do
      expect(SccProxy.singleton_class::ANNOUNCE_URL).to eq('https://scc.suse.com/connect/subscriptions/systems')
    end
  end

  describe 'SYSTEMS_PRODUCTS_URL' do
    it 'appends /systems/products to the base URL' do
      expect(SccProxy.singleton_class::SYSTEMS_PRODUCTS_URL).to eq('https://scc.suse.com/connect/systems/products')
    end
  end

  describe 'SYSTEMS_ACTIVATIONS_URL' do
    it 'appends /systems/activations to the base URL' do
      expect(SccProxy.singleton_class::SYSTEMS_ACTIVATIONS_URL).to eq('https://scc.suse.com/connect/systems/activations')
    end
  end

  describe 'SYSTEMS_URL' do
    it 'appends /systems to the base URL' do
      expect(SccProxy.singleton_class::SYSTEMS_URL).to eq('https://scc.suse.com/connect/systems')
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
