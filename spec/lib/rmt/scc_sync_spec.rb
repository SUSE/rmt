require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::SCCSync do
  describe '#sync', type: :no_transactional do
    let(:product) do
      JSON.parse(file_fixture('products/dummy_product.json').read, symbolize_names: true)
    end
    let(:extension) { product[:extensions][0] }
    let(:all_repositories) { [product, extension].flat_map { |item| item[:repositories] } }
    let(:api_double) { double }

    before do
      expect(SUSE::Connect::Api).to receive(:new) { api_double }
      expect(api_double).to receive(:list_products) { [ product ] }
      sync = described_class.new
      sync.sync
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

        (db_repository.attributes.keys - ['external_url']).each do |key|
          expect(db_repository[key]).to eq(repository[key.to_sym])
        end
      end
    end
  end
end
