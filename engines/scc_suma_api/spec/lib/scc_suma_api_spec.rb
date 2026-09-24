require 'rails_helper'

describe SccSumaApi do
  describe '.suma_base_url' do
    context 'when SCC_HOST is not set' do
      before { ENV.delete('SCC_HOST') }

      it 'uses the default SUSE cloud URL' do
        expect(described_class.suma_base_url).to eq('https://scc.suse.com')
      end
    end

    context 'when SCC_HOST includes /connect' do
      before { ENV['SCC_HOST'] = 'http://localhost:8080/connect' }

      it 'strips /connect' do
        expect(described_class.suma_base_url).to eq('http://localhost:8080')
      end
    end

    context 'when SCC_HOST includes trailing whitespace' do
      before { ENV['SCC_HOST'] = 'https://scc.example.com/connect  ' }

      it 'strips whitespace before removing /connect' do
        expect(described_class.suma_base_url).to eq('https://scc.example.com')
      end
    end
  end

  describe '.repository_url' do
    before { ENV.delete('SCC_HOST') }

    it 'appends /suma/ to the base URL' do
      expect(described_class.repository_url).to eq('https://scc.suse.com/suma/')
    end
  end
end
