require 'rails_helper'

RSpec.describe ServicesController do
  describe '#show' do
    let(:service) { FactoryGirl.create(:service, :with_repositories) }

    describe 'HTTP response' do
      subject { response }

      context 'when service doesn\'t exist' do
        before { get '/services/0' }
        its(:code) { is_expected.to eq '404' }
      end

      context 'when service exists' do
        before { get "/services/#{service.id}" }
        its(:code) { is_expected.to eq '200' }
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
end
