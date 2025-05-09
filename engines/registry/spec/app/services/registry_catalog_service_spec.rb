require 'spec_helper'

describe RegistryCatalogService do
  subject(:registry) { described_class.new }

  let(:system) { create(:system) }
  let(:root_url) { 'registry-example.susecloud.net' }
  let(:auth_url) { "https://#{root_url}/api/registry/authorize" }
  let(:params) { "account=#{system.login}&scope=registry:catalog:*&service=SUSE%20Linux%20OCI%20Registry" }
  let(:response) { { repositories: repositories_returned } }
  let(:repositories_returned) do
    %w[repo repo.v2 level1/repo.v2 level1/level2 level1/level2/repo level1/level2/level.3 level1/level2/level.3/repo]
  end
  let(:registry_conf) { { root_url: root_url } }

  before do
    stub_request(:get, "#{auth_url}?#{params}").with(
      headers: {
        'Accept' => '*/*',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'User-Agent' => 'Ruby'
      }
).to_return(
  status: 200, body: JSON.dump({ token: 'foo_token' }), headers: {}
      )

    stub_request(:get, "#{registry.catalog_api_url}?n=1000")
      .to_return(body: JSON.dump(response), status: 200, headers: { 'Content-type' => 'application/json' })
  end

  it 'lists all repos' do
    allow(System).to receive(:where).and_return([system])
    expect(registry.repos(system).length).to eq repositories_returned.size
  end
end
