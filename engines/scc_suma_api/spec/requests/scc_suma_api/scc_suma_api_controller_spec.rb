require 'rails_helper'
require 'json'

# rubocop:disable Metrics/ModuleLength
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

            its(:headers) do
              expect(headers['location']).to include 'http://www.example.com/api/scc/unscoped-products'
            end
          end

          context 'endpoints return unscoped products for PAYG systems' do
            before do
              get '/api/scc/unscoped-products', headers: payload
            end

            its(:code) { is_expected.to eq '200' }
            its(:body) { is_expected.to eq products.to_json.to_s }
          end

          context 'endpoints return unscoped products for BYOS systems' do
            before do
              allow_any_instance_of(InstanceVerification::Providers::Example).to(
                receive(:instance_valid?).and_return(false)
                )
              allow(System).to receive(:find_by).and_return 'foo'

              allow(SUSE::Connect::Api).to receive(:new).and_return api_double
              allow(api_double).to receive(:list_products_unscoped).and_return products
              File.delete(unscoped_file) if File.exist?(unscoped_file)

              get '/api/scc/unscoped-products', headers: payload
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

        context 'metadata is not valid' do
          let(:error_payload) do
            {
              'X-INSTANCE-IDENTIFIER' => 'Raise error',
              'X-INSTANCE-VERSION' => product.version,
              'X-INSTANCE-ARCH' => product.arch
            }
          end

          before do
            allow(SUSE::Connect::Api).to receive(:new).and_return api_double
            allow(api_double).to receive(:list_products_unscoped).and_return products
            allow(RMT::Logger).to receive(:new).and_return(logger)
            File.delete(unscoped_file) if File.exist?(unscoped_file)
            get '/api/scc/unscoped-products', headers: error_payload
          end

          it 'raise an exception' do
            expect(response.code).to eq '422'
            expect(response.parsed_body['error']).to eq 'Missing signature'
          end
        end
      end

      context 'get repos redirect' do
        before { get '/connect/organizations/repositories' }

        its(:code) { is_expected.to eq '301' }

        its(:headers) do
          expect(headers['location']).to eq 'http://www.example.com/api/scc/repos'
        end
      end

      context 'get subs and orders' do
        before { get '/api/scc/subs' }

        its(:code) { is_expected.to eq '200' }
        its(:body) { is_expected.to eq '[]' }
      end

      context 'get repos' do
        let(:base_product) { FactoryBot.create(:product, :with_mirrored_repositories) }
        let(:entitled_product) { FactoryBot.create(:product, :with_mirrored_repositories) }
        let(:unentitled_product) { FactoryBot.create(:product, :with_mirrored_repositories) }
        let(:add_on) { 'SMS' }
        let(:payload) do
          {
            'X-INSTANCE-IDENTIFIER' => base_product.identifier,
            'X-INSTANCE-VERSION' => base_product.version,
            'X-INSTANCE-ARCH' => base_product.arch
          }
        end

        before do
          allow_any_instance_of(InstanceVerification::Providers::Example).to(
            receive(:instance_valid?).and_return(true)
            )
          allow_any_instance_of(InstanceVerification::Providers::Example).to(
            receive(:add_on).and_return(add_on)
            )
          unentitled_product
        end

        context 'with a subscription granting the add-on product class' do
          before do
            FactoryBot.create(:subscription, product_classes: [add_on, entitled_product.product_class])
            get '/api/scc/repos', headers: payload
          end

          its(:code) { is_expected.to eq '200' }

          it 'returns the repositories of every product class the subscription grants' do
            expect(response.parsed_body.pluck('id')).to match_array(entitled_product.repositories.map(&:scc_id))
          end

          it 'returns the SCC repository object' do
            expect(response.parsed_body.first.keys).to(
              match_array(%w[id name description url enabled autorefresh installer_updates])
              )
          end

          it 'returns URLs served by this update server' do
            expect(response.parsed_body.pluck('url')).to all(start_with('http://www.example.com/repo/'))
          end
        end

        context 'when the add-on product class is not granted by any subscription' do
          before { get '/api/scc/repos', headers: payload }

          its(:code) { is_expected.to eq '200' }
          its(:body) { is_expected.to eq '[]' }
        end

        context 'when the provider reports no add-on' do
          let(:add_on) { nil }

          before do
            FactoryBot.create(:subscription, product_classes: [base_product.product_class, entitled_product.product_class])
            get '/api/scc/repos', headers: payload
          end

          it 'falls back to the base product class' do
            expect(response.parsed_body.pluck('id')).to(
              match_array((base_product.repositories + entitled_product.repositories).map(&:scc_id))
              )
          end
        end

        context 'with repositories that have never been mirrored' do
          let(:entitled_product) { FactoryBot.create(:product, :with_not_mirrored_repositories) }

          before do
            FactoryBot.create(:subscription, product_classes: [add_on, entitled_product.product_class])
            get '/api/scc/repos', headers: payload
          end

          its(:body) { is_expected.to eq '[]' }
        end

        context 'with custom repositories' do
          before do
            FactoryBot.create(:subscription, product_classes: [add_on, entitled_product.product_class])
            entitled_product.repositories.update_all(scc_id: nil)
            get '/api/scc/repos', headers: payload
          end

          it 'never returns a null id' do
            expect(response.parsed_body.pluck('id')).not_to include(nil)
          end
        end

        context 'metadata is not valid' do
          let(:payload) { super().merge('X-INSTANCE-IDENTIFIER' => 'Raise error') }

          before { get '/api/scc/repos', headers: payload }

          it 'raise an exception' do
            expect(response.code).to eq '422'
            expect(response.parsed_body['error']).to eq 'Missing signature'
          end
        end
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

          its(:headers) do
            expect(headers['location']).to eq 'http://www.example.com/api/scc/product-tree'
          end
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
# rubocop:enable Metrics/ModuleLength
