require 'rails_helper'
require 'json'

module SccSumaApi
  RSpec.describe SccSumaApiController, type: :request do
    subject { response }

    describe '#scc endpoints' do
      let!(:products) { JSON.parse(file_fixture('products/dummy_products.json').read, symbolize_names: true) }
      let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }
      let(:api_double) { instance_double 'SUSE::Connect::Api' }
      let(:downloader_double) { instance_double 'RMT::Downloader' }
      let(:product) { FactoryBot.create(:product, :product_sles_sap, :with_mirrored_repositories, :with_mirrored_extensions) }
      let(:payload) do
        {
          'X-INSTANCE-IDENTIFIER' => product.identifier,
          'X-INSTANCE-VERSION' => product.version,
          'X-INSTANCE-ARCH' => product.arch
        }
      end
      let(:logger) { instance_double('RMT::Logger').as_null_object }


      context 'get unscoped products' do
        let(:unscoped_file) { Rails.root.join('tmp/unscoped_products.json') }

        context 'cache is valid' do
          before do
            allow(plugin_double).to(
              receive(:instance_valid?)
                .and_return(true)
              )
            allow(SUSE::Connect::Api).to receive(:new).and_return api_double
            allow(api_double).to receive(:list_products_unscoped).and_return products
            allow(RMT::Logger).to receive(:new).and_return(logger)
            FileUtils.cp(
              file_fixture('products/dummy_products.json'),
              Rails.root.join('tmp/unscoped_products.json')
              )

            get '/api/scc/unscoped-products', headers: payload
          end

          after { File.delete(unscoped_file) if File.exist?(unscoped_file) }

          context 'redirect from SCC endpoint' do
            before do
              get '/connect/organizations/products/unscoped', params: payload
            end

            its(:code) { is_expected.to eq '301' }
            its(:body) { is_expected.to include 'http://www.example.com/api/scc/unscoped-products' }
          end

          context 'endpoints return unscoped products' do
            before do
              get '/api/scc/unscoped-products', params: payload
            end

            its(:code) { is_expected.to eq '200' }
            its(:body) { is_expected.to eq products.to_json.to_s }
          end
        end

        context 'cache is not valid' do
          before do
            allow(plugin_double).to(
              receive(:instance_valid?)
                .and_return(true)
              )
            allow(SUSE::Connect::Api).to receive(:new).and_return api_double
            allow(api_double).to receive(:list_products_unscoped).and_return products
            allow(RMT::Logger).to receive(:new).and_return(logger)
            File.delete(unscoped_file) if File.exist?(unscoped_file)

            get '/api/scc/unscoped-products', headers: payload
          end

          its(:code) { is_expected.to eq '200' }
          its(:body) { is_expected.to eq products.to_json.to_s }
        end
      end

      context 'get repos redirect' do
        before { get '/connect/organizations/repositories' }

        its(:code) { is_expected.to eq '301' }
        its(:body) { is_expected.to include 'http://www.example.com/api/scc/repos' }
      end

      context 'get repos' do
        before { get '/api/scc/repos' }

        its(:code) { is_expected.to eq '200' }
        its(:body) { is_expected.to eq '[]' }
      end

      context 'get product tree' do
        let(:product_tree_file) { Rails.root.join('tmp/product_tree.json') }

        before do
          allow(RMT::Downloader).to receive(:new).and_return downloader_double
          allow(downloader_double).to receive(:download_multi)
          allow_any_instance_of(File).to receive(:read).and_return products.to_json
          FileUtils.cp(file_fixture('products/dummy_products.json'), product_tree_file)

          get '/suma/product_tree.json'
        end

        after { File.delete(product_tree_file) if File.exist?(product_tree_file) }

        context 'SCC endpoint redirect' do
          before do
            get '/suma/product_tree.json'
          end

          its(:code) { is_expected.to eq '301' }
          its(:body) { is_expected.to include 'http://www.example.com/api/scc/product-tree' }
        end

        context 'endpoint returns product tree json output' do
          before do
            get '/api/scc/product-tree'
          end

          its(:code) { is_expected.to eq '200' }
          its(:body) { is_expected.to eq products.to_json.to_s }
        end
      end
    end
  end
end
