require 'rails_helper'

# rubocop:disable RSpec/MultipleExpectations

describe RMT::SCC do
  let!(:products) { JSON.parse(file_fixture('products/dummy_products.json').read, symbolize_names: true) }
  let!(:subscriptions) { JSON.parse(file_fixture('subscriptions/dummy_subscriptions.json').read, symbolize_names: true) }
  let(:extension) { product[:extensions][0] }
  let(:all_repositories) do
    products.flat_map do |product|
      [product, product[:extensions][0]].flat_map { |item| item[:repositories] }
    end
  end
  let(:api_double) { instance_double 'SUSE::Connect::Api' }

  shared_examples 'saves in database' do
    it 'saves products to the DB' do
      products.each do |product|
        extension = product[:extensions][0]

        [product, extension].each do |product|
          db_product = Product.find(product[:id])
          db_product.attributes.each do |key, value|
            expect(value).to eq(product[key.to_sym])
          end
        end
      end
    end

    it 'saves repos to the DB' do
      all_repositories.map.each do |repository|
        db_repository = Repository.find_by(scc_id: repository[:id])

        (db_repository.attributes.keys - %w[id scc_id external_url mirroring_enabled local_path]).each do |key|
          expect(db_repository[key].to_s).to eq(repository[key.to_sym].to_s)
        end
        expect(db_repository[:scc_id]).to eq(repository[:id])
      end
    end

    it 'saves subscriptions to the DB' do
      subscriptions.map.each do |subscription|
        db_subscription = Subscription.find(subscription[:id])

        (db_subscription.attributes.keys - %w[kind status created_at updated_at]).each do |key|
          expect(db_subscription[key]).to eq(subscription[key.to_sym])
        end

        expect(db_subscription[:kind]).to eq(subscription[:type])
        expect(Subscription.statuses[db_subscription.status]).to eq(subscription[:status])
      end
    end
  end

  before do
    allow(SUSE::Connect::Api).to receive(:new).and_return api_double
    allow(api_double).to receive(:list_products).and_return products
    allow(api_double).to receive(:list_products_unscoped).and_return products
    allow(api_double).to receive(:list_repositories).and_return all_repositories
    allow(api_double).to receive(:list_subscriptions).and_return subscriptions
    allow(api_double).to receive(:list_orders).and_return []

    # disable output to stdout while running specs
    allow(STDOUT).to receive(:puts)
    allow(STDOUT).to receive(:write)
    # disable Logger output while running tests
    logger = instance_double('Logger').as_null_object
    allow(Logger).to receive(:new).and_return(logger)
  end

  describe '#sync' do
    context 'without SCC credentials' do
      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new
      end

      it 'raises an error' do
        expect { described_class.new.sync }.to raise_error RMT::SCC::CredentialsError, 'SCC credentials not set.'
      end
    end

    context 'with SCC credentials' do
      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new(username: 'foo', password: 'bar')
        described_class.new.sync
      end

      include_examples 'saves in database'
    end
  end

  describe '#remove_suse_repos_without_tokens' do
    let(:api_double) { double }
    let!(:suse_repo_with_token) { FactoryGirl.create(:repository, :with_products, auth_token: 'auth_token') }
    let!(:suse_repo_without_token) do
      FactoryGirl.create(
        :repository,
        :with_products,
        auth_token: nil,
        external_url: 'https://updates.suse.com/repos/dummy/'
      )
    end
    let!(:other_repo_without_token) do
      FactoryGirl.create(
        :repository,
        :with_products,
        auth_token: nil,
        external_url: 'https://example.com/repos/not/updates.suse.com/'
      )
    end

    before do
      # to prevent 'does not implement' verifying doubles error
      Settings.class_eval do
        def scc
        end
      end

      allow(Settings).to receive(:scc).and_return OpenStruct.new(username: 'foo', password: 'bar')

      expect(SUSE::Connect::Api).to receive(:new) { api_double }
      expect(api_double).to receive(:list_products) { [] }
      expect(api_double).to receive(:list_repositories) { [] }
      expect(api_double).to receive(:list_subscriptions) { [] }

      # disable output to stdout while running specs
      allow(STDOUT).to receive(:puts)
      allow(STDOUT).to receive(:write)

      described_class.new.sync
    end

    it 'SUSE repos with auth_tokens persist' do
      expect { suse_repo_with_token.reload }.not_to raise_error
    end

    it 'SUSE repos without auth_tokens are removed' do
      expect { suse_repo_without_token.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'other repos without auth_tokens persist' do
      expect { other_repo_without_token.reload }.not_to raise_error
    end
  end

  describe '#export' do
    let(:path) { '/tmp/usb' }

    context 'without SCC credentials' do
      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new
      end

      it 'raises an error' do
        expect { described_class.new.export(path) }.to raise_error RMT::SCC::CredentialsError, 'SCC credentials not set.'
      end
    end

    context 'with SCC credentials' do
      before do
        allow(Settings).to receive(:scc).and_return(OpenStruct.new(username: 'me', password: 'groot'))
      end

      %w[orders products products_scoped repositories subscriptions].each do |data|
        it "writes #{data} file to path" do
          FakeFS.with_fresh do
            FileUtils.mkdir_p path
            described_class.new.export(path)
            expect(File.exist?(File.join(path, "organizations_#{data}.json")))
          end
        end
      end
    end
  end

  describe '#import' do
    let(:path) { '/tmp/usb' }

    context 'with bad path or missing files' do
      it 'raises an error before it touches the database' do
        FakeFS.with_fresh do
          expect(ApplicationRecord).not_to receive(:delete_all)
          expect(ApplicationRecord).not_to receive(:update)
          expect(ApplicationRecord).not_to receive(:new)
          expect { described_class.new.import(path) }.to raise_error RMT::SCC::DataFilesError
        end
      end
    end

    context 'with good path and files' do
      before do
        FakeFS.with_fresh do
          FileUtils.mkdir_p(path)
          File.write(File.join(path, 'organizations_products_scoped.json'), products.to_json)
          File.write(File.join(path, 'organizations_subscriptions.json'), subscriptions.to_json)
          File.write(File.join(path, 'organizations_repositories.json'), all_repositories.to_json)

          described_class.new.import(path)
        end
      end

      include_examples 'saves in database'
    end
  end
end
