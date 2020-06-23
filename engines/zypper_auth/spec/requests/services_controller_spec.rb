require 'rails_helper'

describe ServicesController do
  include_context 'auth header', :system, :login, :password

  before { Rails.cache.clear }

  describe '#show' do
    subject(:xml_urls) do
      doc = Nokogiri::XML::Document.parse(response.body)
      repo_items = doc.xpath('/repoindex/repo')
      repo_items.map { |r| r.attr(:url) }
    end

    let(:system) { FactoryGirl.create(:system, :with_activated_product) }
    let(:service) { system.products.first.service }

    context 'without X-Instance-Data header' do
      let(:headers) { auth_header }

      before do
        expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(false)
        get "/services/#{service.id}", headers: headers
      end

      it 'repo URLs have http scheme' do
        expect(xml_urls).to all(match(%r{^http://}))
      end
    end

    context 'with X-Instance-Data header' do
      let(:headers) { auth_header.merge('X-Instance-Data' => 'test') }

      context 'when instance verification succeeds' do
        before do
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(true)
          get "/services/#{service.id}", headers: headers
        end

        it 'request succeeds' do
          expect(response).to have_http_status(200)
        end

        it 'XML has all product repos' do
          expect(xml_urls.size).to eq(system.products.first.repositories.size)
        end

        it 'repo URLs have plugin:/susecloud scheme' do
          expect(xml_urls).to all(match(%r{^plugin:/susecloud}))
        end
      end

      context 'when instance verification returns false' do
        before do
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_return(false)
          get "/services/#{service.id}", headers: headers
        end

        it 'request fails with 403' do
          expect(response).to have_http_status(403)
        end

        it 'reports an error' do
          expect(response.body).to match(/Instance verification failed/)
        end
      end

      context 'when instance verification raises StandardError' do
        before do
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_raise('Test')
          get "/services/#{service.id}", headers: headers
        end

        it 'request fails with 403' do
          expect(response).to have_http_status(403)
        end

        it 'reports an error' do
          expect(response.body).to match(/Instance verification failed/)
        end
      end

      context 'when instance verification raises InstanceVerification::Exception' do
        before do
          expect_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_valid?).and_raise(InstanceVerification::Exception, 'Test')
          get "/services/#{service.id}", headers: headers
        end

        it 'request fails with 403' do
          expect(response).to have_http_status(403)
        end

        it 'reports an error' do
          expect(response.body).to match(/Instance verification failed/)
        end
      end
    end
  end
end
