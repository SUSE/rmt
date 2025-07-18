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

    let(:system) { FactoryBot.create(:system, :byos, :with_activated_product) }
    let(:service) { system.products.first.service }

    context 'without X-Instance-Data header' do
      let(:headers) { auth_header }

      before do
        Thread.current[:logger] = RMT::Logger.new('/dev/null')
        allow(File).to receive(:directory?)
        allow(FileUtils).to receive(:mkdir_p)
        allow(FileUtils).to receive(:touch)
        get "/services/#{service.id}", headers: headers
      end

      it 'repo URLs have http scheme' do
        expect(xml_urls).to all(match(%r{^http://}))
      end
    end

    context 'with X-Instance-Data header' do
      let(:headers) { auth_header.merge('X-Instance-Data' => 'test') }
      let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

      context 'when instance verification succeeds' do
        let(:data_export_double) { instance_double('DataExport::Handlers::Example') }

        before do
          allow(InstanceVerification).to receive(:verify_instance).and_return(true)
          get "/services/#{service.id}", headers: headers
        end

        it 'request succeeds' do
          expect(response).to have_http_status(200)
        end

        it 'XML has all product repos' do
          expect(xml_urls.size).to eq(system.products.first.repositories.size - 1)
        end

        it 'repo URLs have plugin:/susecloud scheme' do
          expect(xml_urls).to all(match(%r{^plugin:/susecloud}))
        end
      end

      context 'when instance verification returns false' do
        before do
          stub_request(:get, 'https://scc.suse.com/connect/systems/activations')
            .to_return(status: 200, body: '', headers: {})
          expect(InstanceVerification).to receive(:build_cache_entry).with(
            '127.0.0.1', system.login, {}, system.proxy_byos_mode, system.products.find_by(product_type: 'base')
          )
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
