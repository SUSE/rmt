require 'set'

shared_examples 'products controller action' do
  context 'when no credentials are provided' do
    before { send(verb, url) }
    subject { response }

    its(:code) { is_expected.to eq '401' }
  end

  context 'when required parameters are missing' do
    it 'raises an error' do
      expect { send(verb, url, headers: headers) }.to raise_error ActionController::ParameterMissingTranslated
    end
  end

  context 'when product has no repos' do
    let(:product_without_repos) { FactoryGirl.create(:product) }
    let(:payload) do
      {
          identifier: product_without_repos.identifier,
          version: product_without_repos.version,
          arch: product_without_repos.arch
      }
    end

    it 'raises an error' do
      expect { send(verb, url, headers: headers, params: payload) }.to raise_error(/No repositories found for product/)
    end
  end

  context 'when product does not exist' do
    let(:payload) do
      {
          identifier: -1,
          version: product_with_repos.version,
          arch: product_with_repos.arch
      }
    end

    before { send(verb, url, headers: headers, params: payload) }
    subject { response }

    its(:code) { is_expected.to eq('422') }

    describe 'JSON response' do
      subject { JSON.parse(response.body, symbolize_names: true) }
      its([:error]) { is_expected.to eq('No product found') }
    end
  end
end
