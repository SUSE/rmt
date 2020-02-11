require 'rails_helper'

describe RMT::SCC do
  let!(:products) { JSON.parse(file_fixture('products/dummy_products.json').read, symbolize_names: true) }
  let!(:subscriptions) { JSON.parse(file_fixture('subscriptions/dummy_subscriptions.json').read, symbolize_names: true) }
  let(:extension) { product[:extensions][0] }
  let(:all_repositories) do
    repos = products.flat_map do |product|
      [product, product[:extensions][0]].flat_map { |item| item[:repositories] }
    end

    # Adding tokens to repository URLs, as organization/repositories endpoint does
    repos.deep_dup.map do |item|
      item[:url] += "?token_#{item[:id]}"
      item
    end
  end
  let(:api_double) { instance_double 'SUSE::Connect::Api' }
  let(:logger) { instance_double('RMT::Logger').as_null_object }


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

    it 'creates the correct predecessor association when predecessor exists' do
      products.each do |product_data|
        extension = product_data[:extensions][0]

        [product_data, extension].each do |product|
          product[:online_predecessor_ids].each do |id|
            expect(find_predecessor_association(product[:id], :online, id)).to be_persisted unless Product.find_by(id: id).nil?
          end
          product[:offline_predecessor_ids].each do |id|
            expect(find_predecessor_association(product[:id], :offline, id)).to be_persisted unless Product.find_by(id: id).nil?
          end
        end
      end
    end

    it 'saves repos to the DB' do
      all_repositories.map.each do |repository|
        db_repository = Repository.find_by(scc_id: repository[:id])

        (db_repository.attributes.keys - %w[id scc_id external_url mirroring_enabled local_path auth_token]).each do |key|
          expect(db_repository[key].to_s).to eq(repository[key.to_sym].to_s)
        end
        expect(db_repository[:scc_id]).to eq(repository[:id])

        uri = URI(repository[:url])
        auth_token = uri.query
        uri.query = nil

        expect(db_repository[:external_url]).to eq(uri.to_s)
        expect(db_repository[:auth_token]).to eq(auth_token)
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
    allow(RMT::Logger).to receive(:new).and_return(logger)
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

    context 'with SLES15 product tree' do
      let(:products) { JSON.parse(file_fixture('products/sle15_tree.json').read, symbolize_names: true) }
      let(:subscriptions) { [] }
      let(:all_repositories) { [] }

      let(:sles) { Product.find_by(identifier: 'SLES') }
      let(:sled) { Product.find_by(identifier: 'SLED') }

      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new(username: 'foo', password: 'bar')
        described_class.new.sync
      end

      include_examples 'saves in database'

      it 'SLES has the correct extension tree' do
        basesystem = sles.extensions.first
        desktop = basesystem.extensions.for_root_product(sles).first
        sle_we  = desktop.extensions.for_root_product(sles).first

        expect([basesystem, desktop, sle_we].map(&:identifier)).to eq(
          ['sle-module-basesystem', 'sle-module-desktop', 'sle-module-we']
        )
      end

      it 'SLED has the correct extension tree' do
        basesystem = sled.extensions.first
        desktop = basesystem.extensions.for_root_product(sled).first
        productivity = desktop.extensions.for_root_product(sled).first

        expect([basesystem, desktop, productivity].map(&:identifier)).to eq(
          ['sle-module-basesystem', 'sle-module-desktop', 'sle-module-desktop-productivity']
        )
      end
    end

    context "with extensions that don't have base products available" do
      let(:extra_repo) do
        {
          id: 999999,
          url: 'http://example.com/extension-without-base',
          name: 'Repo of an extension without base'
        }
      end
      let(:extra_product) do
        {
          id: 999999,
          identifier: 'ext-without-base',
          version: '99',
          arch: 'x86_64',
          name: 'Extension without base',
          friendly_name: 'Extension without base',
          repositories: [ extra_repo ],
          extensions: [],
          online_predecessor_ids: [],
          offline_predecessor_ids: []
        }
      end
      let(:repositories_with_extra_repos) { all_repositories + [extra_repo] }
      let(:products_with_extra_extension) { products + [extra_product] }

      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new(username: 'foo', password: 'bar')
        allow(api_double).to receive(:list_products).and_return products_with_extra_extension
        allow(api_double).to receive(:list_repositories).and_return repositories_with_extra_repos
        described_class.new.sync
      end

      it 'saves extensions without base products' do
        expect(Product.find(extra_product[:id]).identifier).to eq(extra_product[:identifier])
      end

      it "doesn't save repos of extensions without base products" do
        expect { Repository.find(extra_repo[:id]) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with existing predecessor associations' do
      let(:product) { create(:product, id: 100000) }
      let(:predecessor) { create(:product, id: 500000) }
      let!(:existing_association) do
        ProductPredecessorAssociation.create(product_id: product.id, predecessor_id: predecessor.id, kind: :online)
      end

      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new(username: 'foo', password: 'bar')
        described_class.new.sync
      end

      it 'removes existing predecessor associations' do
        expect { ProductPredecessorAssociation.find(existing_association.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
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

      %w[orders products_unscoped products repositories subscriptions].each do |data|
        it "writes #{data} file to path" do
          FakeFS.with_fresh do
            FileUtils.mkdir_p path
            described_class.new.export(path)
            expect(File).to exist(File.join(path, "organizations_#{data}.json"))
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
          File.write(File.join(path, 'organizations_products.json'), products.to_json)
          File.write(File.join(path, 'organizations_subscriptions.json'), subscriptions.to_json)
          File.write(File.join(path, 'organizations_repositories.json'), all_repositories.to_json)

          described_class.new.import(path)
        end
      end

      include_examples 'saves in database'
    end
  end

  describe '#sync_systems' do
    context 'when system syncing is disabled' do
      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new(
          username: 'foo',
          password: 'bar',
          sync_systems: false
        )
      end

      it "doesn't sync systems" do
        expect(api_double).not_to receive(:forward_system_activations)
        described_class.new.sync_systems
      end

      it 'produces a warning' do
        expect(logger).to receive(:warn).with(/Syncing systems to SCC is disabled by the configuration file, exiting/)
        described_class.new.sync_systems
      end
    end

    context 'when system syncing is enabled' do
      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new(
          username: 'foo',
          password: 'bar',
          sync_systems: true
        )
      end

      context 'when syncing succeeds' do
        before do
          expect(api_double).to receive(:forward_system_activations).with(system).and_return(
            {
              id: scc_system_id,
              login: 'test',
              password: 'test'
            }
          )
          expect(api_double).to receive(:forward_system_deregistration).with(deregistered_system.scc_system_id)

          expect(logger).to receive(:info).with(/Syncing system/)
          expect(logger).to receive(:info).with(/Syncing de-registered system/)
          described_class.new.sync_systems
        end

        let(:system) { FactoryGirl.create(:system) }
        let(:scc_system_id) { 9000 }
        let(:deregistered_system) { FactoryGirl.create(:deregistered_system) }

        it 'updates system.scc_registered_at field' do
          system.reload
          expect(system.scc_registered_at).not_to be(nil)
        end

        it 'updates system.scc_system_id field' do
          system.reload
          expect(system.scc_system_id).to be(scc_system_id)
        end
      end

      context 'when syncing fails' do
        before do
          expect(api_double).to receive(:forward_system_activations).with(system).and_raise(SUSE::Connect::Api::RequestError, 'Sync error')
          expect(logger).to receive(:info).with(/Syncing system/)
          expect(logger).to receive(:error).with(/Failed to sync system/)
          described_class.new.sync_systems
        end

        let(:system) { FactoryGirl.create(:system) }

        it "doesn't update system.scc_registered_at" do
          system.reload
          expect(system.scc_registered_at).to be(nil)
        end
      end
    end
  end

  def find_predecessor_association(product_id, kind, predecessor_id)
    ProductPredecessorAssociation.find_by(product_id: product_id, kind: kind, predecessor_id: predecessor_id)
  end
end
