require 'set'

shared_examples 'products controller action' do
  before { send(verb, url, headers: headers, params: payload) }
  subject { response }

  context 'when no credentials are provided' do
    let(:headers) { {} }
    let(:payload) { {} }

    before { send(verb, url) }
    subject { response }

    its(:code) { is_expected.to eq '401' }
  end

  context 'when required parameters are missing' do
    let(:payload) { {} }

    its(:code) { is_expected.to eq('422') }

    describe 'JSON response' do
      subject { JSON.parse(response.body, symbolize_names: true) }
      its([:error]) { is_expected.to match(/Required parameters are missing or empty/) }
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

    its(:code) { is_expected.to eq('422') }

    describe 'JSON response' do
      subject { JSON.parse(response.body, symbolize_names: true) }
      its([:error]) { is_expected.to match(/No repositories found for product/) }
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

    its(:code) { is_expected.to eq('422') }

    describe 'JSON response' do
      subject { JSON.parse(response.body, symbolize_names: true) }
      its([:error]) { is_expected.to eq('No product found') }
    end
  end
end
