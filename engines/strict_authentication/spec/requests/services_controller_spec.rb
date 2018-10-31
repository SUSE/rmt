require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe ServicesController, type: :request do
  describe '#show' do
    let(:service) { FactoryGirl.create(:service, :with_repositories) }
    let(:system) { FactoryGirl.create(:system) }

    describe 'HTTP response' do
      context 'without authentication' do
        subject { response }

        context 'when service doesn\'t exist' do
          before { get '/services/0' }
          its(:code) { is_expected.to eq '401' }
        end

        context 'when service exists' do
          before { get "/services/#{service.id}" }
          its(:code) { is_expected.to eq '401' }
        end
      end

      context 'with authentication' do
        subject { response }

        include_context 'auth header', :system, :login, :password

        context 'when service doesn\'t exist' do
          before { get '/services/0', headers: auth_header }
          its(:code) { is_expected.to eq '404' }
        end

        context 'when service exists' do
          before { get "/services/#{service.id}", headers: auth_header }
          its(:code) { is_expected.to eq '200' }
        end
      end
    end

    describe 'response XML URLs' do
      before { get "/services/#{service.id}", headers: auth_header }

      include_context 'auth header', :system, :login, :password

      subject { xml_urls }

      let(:xml_urls) do
        doc = Nokogiri::XML::Document.parse(response.body)
        repo_items = doc.xpath('/repoindex/repo')
        repo_items.map { |r| r.attr(:url) }
      end

      let(:model_urls) do
        service.repositories.map do |repo|
          RMT::Misc.make_repo_url('http://www.example.com', repo.local_path)
        end
      end

      its(:length) { is_expected.to eq(service.repositories.length) }
      it { is_expected.to eq(model_urls) }
    end
  end
end

# rubocop:enable RSpec/NestedGroups
