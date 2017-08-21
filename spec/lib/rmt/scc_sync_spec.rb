require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::SCCSync do
  describe '#sync' do
    context 'with SCC credentials' do
      let(:product) do
        JSON.parse(file_fixture('products/dummy_product.json').read, symbolize_names: true)
      end
      let(:extension) { product[:extensions][0] }
      let(:all_repositories) { [product, extension].flat_map { |item| item[:repositories] } }
      let(:api_double) { double }

      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new(username: 'foo', password: 'bar')

        expect(SUSE::Connect::Api).to receive(:new) { api_double }
        expect(api_double).to receive(:list_products) { [ product ] }
        expect(api_double).to receive(:list_repositories) { all_repositories }

        # disable output to stdout while running specs
        allow(STDOUT).to receive(:puts)
        allow(STDOUT).to receive(:write)

        described_class.new.sync
      end

      it 'saves products to the DB' do
        [product, extension].each do |product|
          db_product = Product.find(product[:id])
          db_product.attributes.each do |key, value|
            expect(value).to eq(product[key.to_sym])
          end
        end
      end

      it 'saves repos to the DB' do
        all_repositories.map.each do |repository|
          db_repository = Repository.find(repository[:id])

          (db_repository.attributes.keys - %w[external_url mirroring_enabled local_path]).each do |key|
            expect(db_repository[key]).to eq(repository[key.to_sym])
          end
        end
      end
    end

    context 'without SCC credentials' do
      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new
      end

      it 'exits with an error message' do
        expect { described_class.new.sync }.to raise_error RMT::SCCSync::CredentialsError
      end
    end
  end
end
