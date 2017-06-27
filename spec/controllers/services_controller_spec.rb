require 'rails_helper'

RSpec.describe ServicesController, type: [:request, :controller] do
  let(:service) do
    FactoryGirl.create(:service_with_repositories)
  end

  before(:each) do
    get "/services/#{service.id}"
  end

  render_views

  context 'service XML' do
    before(:each) do
      doc = Nokogiri::XML::Document.parse(response.body)
      repo_items = doc.xpath('/repoindex/repo')
      @repo_urls = repo_items.map {|r| r.attr(:url) }
    end

    it 'returns code 200' do
      expect(response.code).to eq('200')
    end

    context 'structure' do
      it('has repositories') { expect(@repo_urls.length).to be > 0 }
      it('has right number of repos') { expect(@repo_urls.length).to eq(service.repositories.length) }
      it('has right URLs') {
        urls = service.repositories.map {|repo|
          SUSE::Misc.uri_replace_hostname(repo.external_url, request.scheme, request.host, request.port).to_s
        }

        expect(@repo_urls).to eq(urls)
      }
    end
  end
end
