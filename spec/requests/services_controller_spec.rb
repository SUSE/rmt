require 'rails_helper'

RSpec.describe ServicesController do
  describe '#show' do
    let(:service) { FactoryGirl.create(:service, :with_repositories) }

    describe 'HTTP response' do
      subject { response }

      context 'when service doesn\'t exist' do
        before { get '/services/0' }
        it { is_expected.to have_http_status(404) }
      end

      context 'when service exists' do
        before { get "/services/#{service.id}" }
        it { is_expected.to have_http_status(200) }
      end
    end

    describe 'response XML URLs' do
      before { get "/services/#{service.id}" }

      subject { xml_urls }

      let(:xml_urls) do
        doc = Nokogiri::XML::Document.parse(response.body)
        repo_items = doc.xpath('/repoindex/repo')
        repo_items.map { |r| r.attr(:url) }
      end

      let(:model_urls) do
        service.repositories.map do |repo|
          RMT::Misc.make_repo_url('http://www.example.com', repo.local_path, service.name)
        end
      end

      its(:length) { is_expected.to eq(service.repositories.length) }
      it { is_expected.to eq(model_urls) }
    end
  end

  describe '#legacy_service' do
    include_context 'auth header', :system, :login, :password

    subject { response }

    let(:product1) do
      product = FactoryGirl.create(:product, :with_mirrored_repositories)
      product.repositories.where(enabled: false).update(mirroring_enabled: false)
      product
    end
    let(:product2) do
      product = FactoryGirl.create(:product, :with_mirrored_repositories)
      product.repositories.where(enabled: false).update(mirroring_enabled: false)
      product
    end
    let(:system) do
      system = FactoryGirl.create(:system)
      system.activations << [
        FactoryGirl.create(:activation, system: system, service: product1.service),
        FactoryGirl.create(:activation, system: system, service: product2.service)
      ]
      system
    end

    let(:service_name) { RMT::Misc.make_smt_service_name(request.base_url) }
    let(:expected_repos) do
      (
        product1.repositories.where(mirroring_enabled: true) +
        product2.repositories.where(mirroring_enabled: true)
      ).map { |r| RMT::Misc.make_repo_url(request.base_url, r.local_path, service_name) }
    end

    context 'without authentication headers' do
      before { get '/repo/repoindex.xml' }

      it { is_expected.to have_http_status(401) }
    end

    context 'with auth headers' do
      before { get '/repo/repoindex.xml', headers: auth_header }

      let(:xml_urls) do
        doc = Nokogiri::XML::Document.parse(response.body)
        repo_items = doc.xpath('/repoindex/repo')
        repo_items.map { |r| r.attr(:url) }
      end

      it { is_expected.to have_http_status(200) }

      it 'has mirrored repos of multiple products in the XML' do
        expect(xml_urls).to eq(expected_repos)
      end
    end
  end
end
