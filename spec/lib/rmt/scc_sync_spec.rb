require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::SCCSync do
  describe '#sync', type: :no_transactional do
    let(:extension) do
      {
        id: 100001,
        name: 'Dummy Test Module',
        identifier: 'dummy-test-module-x86_64',
        former_identifier: 'dummy-test-module-x86_64',
        version: '42',
        release_type: nil,
        arch: nil,
        friendly_name: 'Dummy Test Module x86_64',
        product_class: 'dtm',
        cpe: nil,
        free: true,
        description: nil,
        release_stage: 'released',
        eula_url: '',
        repositories: [
          {
            id: 200001,
            url: 'https://example.com/repo/dtp/dummy-test-module-x86_64/',
            name: 'DTM Updates',
            distro_target: 'dtm-42-x86_64',
            description: 'DTM Updates',
            enabled: true,
            autorefresh: true,
            installer_updates: false
          }
        ],
        product_type: 'extension',
        predecessor_ids: [],
        shortname: nil,
        extensions: []
      }
    end

    let(:product) do
      {
        id: 100000,
        name: 'Dummy Test Product',
        identifier: 'dummy-test-product-x86_64',
        former_identifier: 'dummy-test-product-x86_64',
        version: '42',
        release_type: nil,
        arch: 'x86_64',
        friendly_name: 'Dummy Test Product x86_64',
        product_class: 'dtp',
        cpe: nil,
        free: false,
        description: nil,
        release_stage: 'released',
        eula_url: '',
        repositories: [
          {
            id: 200000,
            url: 'https://example.com/repo/dtp/dummy-test-product-x86_64/',
            name: 'DTP Updates',
            distro_target: 'dtp-42-x86_64',
            description: 'DTP Updates',
            enabled: true,
            autorefresh: true,
            installer_updates: false
          }
        ],
        product_type: 'base',
        predecessor_ids: [],
        shortname: nil,
        extensions: [ extension ]
      }
    end

    let(:all_repositories) { [product, extension].map(&->(i) { i[:repositories] }).flatten(1) }

    it 'calls list_products API method' do
      api_double = double
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
