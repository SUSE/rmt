require 'rails_helper'

RSpec.describe DeclarativeConfigService do
  describe '.enforce!' do
    let(:repository_service) { instance_double(RepositoryService) }

    before do
      allow(RepositoryService).to receive(:new).and_return(repository_service)
      allow(repository_service).to receive(:change_mirroring_by_product!)
      allow(repository_service).to receive(:update_or_create_repository!)
      allow(Rails.logger).to receive(:info)
    end

    context 'when products is defined and not empty' do
      let(:configured_product_string) { 'SLES/15/x86_64' }
      let(:configured_product) { instance_double(Product, product_string: configured_product_string) }
      let(:unconfigured_product_string) { 'SLED/15/x86_64' }
      let(:unconfigured_product) { instance_double(Product, product_string: unconfigured_product_string) }

      before do
        allow(Settings).to receive(:try).with(:products).and_return([configured_product_string])
        allow(Settings).to receive(:try).with(:custom_repositories).and_return(nil)

        allow(Product).to receive(:get_by_target!).with(configured_product_string).and_return([configured_product])
        allow(Product).to receive(:all).and_return([configured_product, unconfigured_product])
      end

      it 'logs the application of products configuration' do
        expect(Rails.logger).to receive(:info).with('Applying products configuration')
        described_class.enforce!
      end

      it 'enables the configured but not yet enabled product' do
        expect(repository_service).to receive(:change_mirroring_by_product!).with(true, configured_product)
        described_class.enforce!
      end

      it 'disables products that are not present in the configuration' do
        expect(repository_service).to receive(:change_mirroring_by_product!).with(false, unconfigured_product)
        described_class.enforce!
      end
    end

    context 'when custom_repositories is defined and not empty' do
      let(:configured_repos) { { my_repo: 'http://example.com/repo' } }
      let(:custom_repos_relation) { instance_double(ActiveRecord::Relation) }
      let(:existing_repo) { instance_double(Repository, friendly_id: 'my_repo', external_url: 'http://old.com/repo') }
      let(:obsolete_repo) { instance_double(Repository, friendly_id: 'old_repo') }

      before do
        allow(Settings).to receive(:try).with(:products).and_return(nil)
        allow(Settings).to receive(:try).with(:custom_repositories).and_return(configured_repos)

        allow(Repository).to receive(:only_custom).and_return(custom_repos_relation)
        allow(custom_repos_relation).to receive(:find_by).with(friendly_id: 'my_repo').and_return(existing_repo)
        allow(custom_repos_relation).to receive(:each).and_yield(existing_repo).and_yield(obsolete_repo)

        allow(Repository).to receive(:make_local_path).with('http://example.com/repo').and_return('/path/to/repo')

        allow(existing_repo).to receive(:update!)
        allow(obsolete_repo).to receive(:destroy!)
      end

      it 'logs the application of custom repositories configuration' do
        expect(Rails.logger).to receive(:info).with('Applying custom repositories configuration')
        described_class.enforce!
      end

      it 'updates the external_url and local_path if the url of an existing repository changed' do
        expect(existing_repo).to receive(:update!).with(
          external_url: 'http://example.com/repo',
          local_path: '/path/to/repo'
        )
        described_class.enforce!
      end

      it 'delegates creation or updating to the repository service' do
        expect(repository_service).to receive(:update_or_create_repository!).with(
          nil,
          'http://example.com/repo',
          { name: 'my_repo', id: 'my_repo', enabled: true, mirroring_enabled: true },
          custom: true
        )
        described_class.enforce!
      end

      it 'destroys custom repositories that are not in the configuration' do
        expect(obsolete_repo).to receive(:destroy!)
        expect(existing_repo).not_to receive(:destroy!)
        described_class.enforce!
      end
    end

    context 'when settings are nil or empty' do
      before do
        allow(Settings).to receive(:try).with(:products).and_return(nil)
        allow(Settings).to receive(:try).with(:custom_repositories).and_return(nil)
      end

      it 'does not log anything or alter configurations' do
        expect(Rails.logger).not_to receive(:info)
        expect(repository_service).not_to receive(:change_mirroring_by_product!)
        described_class.enforce!
      end
    end
  end
end
