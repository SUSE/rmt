require 'set'

shared_examples 'products controller action' do
  before { send(verb, url, headers: headers, params: payload) }
  subject { response }

  context 'when no credentials are provided' do
    subject { response }

    let(:headers) { {} }
    let(:payload) { {} }

    before { send(verb, url) }
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

  context 'when product does not exist' do
    let(:payload) do
      {
        identifier: -1,
        version: product.version,
        arch: product.arch
      }
    end

    its(:code) { is_expected.to eq('422') }

    describe 'JSON response' do
      subject { JSON.parse(response.body, symbolize_names: true) }

      its([:error]) { is_expected.to eq('No product found') }
    end
  end
end

shared_examples 'product must have mirrored repositories' do
  before { send(verb, url, headers: headers, params: payload) }
  subject { response }

  context 'but the product has no repos' do
    let(:product_without_repos) { FactoryBot.create(:product) }
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

  context "but the product's mandatory repos aren't mirrored" do
    subject { response }

    let(:product) { FactoryBot.create(:product, :with_not_mirrored_repositories) }
    let(:missing_repo_ids) { (product.repositories.only_enabled - product.repositories.only_enabled.only_fully_mirrored).pluck(:id).join(', ') }
    # rubocop:disable Layout/LineLength
    let(:error_json) do
      {
        type: 'error',
        error: "Not all mandatory repositories are mirrored for product #{product.friendly_name}. Missing Repositories (by ids): #{missing_repo_ids}. On the RMT server, the missing repositories can get enabled with: rmt-cli repos enable #{missing_repo_ids};  rmt-cli mirror",
        localized_error: "Not all mandatory repositories are mirrored for product #{product.friendly_name}. Missing Repositories (by ids): #{missing_repo_ids}. On the RMT server, the missing repositories can get enabled with: rmt-cli repos enable #{missing_repo_ids};  rmt-cli mirror"
      }.to_json
    end
    # rubocop:enable Layout/LineLength

    before { post url, headers: headers, params: payload }
    its(:code) { is_expected.to eq('422') }
    its(:body) { is_expected.to eq(error_json) }
  end
end
