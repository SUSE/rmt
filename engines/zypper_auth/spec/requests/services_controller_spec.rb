require 'rails_helper'

describe ServicesController do
  include_context 'auth header', :system, :login, :password

  describe '#show' do
    subject(:xml_urls) do
      doc = Nokogiri::XML::Document.parse(response.body)
      repo_items = doc.xpath('/repoindex/repo')
      repo_items.map { |r| r.attr(:url) }
    end

    let(:system) { FactoryGirl.create(:system, :with_activated_product) }
    let(:service) { system.products.first.service }

    before { get "/services/#{service.id}", headers: headers }

    context 'without X-Instance-Data header' do
      let(:headers) { auth_header }

      it 'repo URLs have http scheme' do
        expect(xml_urls).to all(match(%r{^http://}))
      end
    end

    context 'with X-Instance-Data header' do
      let(:headers) { auth_header.merge('X-Instance-Data' => 'asdasd') }

      it 'repo URLs have plugin:/susecloud scheme' do
        expect(xml_urls).to all(match(%r{^plugin:/susecloud}))
      end
    end
  end
end
