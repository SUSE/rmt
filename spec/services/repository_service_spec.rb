require 'rails_helper'

describe RepositoryService do
  subject(:service) { described_class.new }

  let(:product) { create :product, :with_service }

  describe '#create_repository' do
    subject(:repository) { service.create_repository!(product, url, attributes, custom: custom).reload }

    let(:attributes) do
      {
        name: 'foo',
        mirroring_enabled: true,
        description: 'foo',
        autorefresh: true,
        enabled: false,
        id: id
      }
    end
    let(:url) { 'http://foo.bar/repos' }
    let(:custom) { false }
    let(:id) { '50' }

    shared_examples 'scc repositories' do
      it('creates the repository') { expect(repository.name).to eq('foo') }

      it('has the correct URL') { expect(repository.external_url).to eq(url) }

      it('has the correct friendly_id') { expect(repository.friendly_id).to eq('50') }

      it('has the correct scc_id') { expect(repository.friendly_id).to eq(id) }

      it('is not custom') { expect(repository.custom?).to eq(false) }
    end

    it_behaves_like 'scc repositories'

    context 'URLs of SCC repositories changes' do
      subject(:repository) do
        service.create_repository!(product, old_url, attributes, custom: custom)
        expect(Repository.find_by(external_url: old_url)).not_to eq(nil)

        service.create_repository!(product, url, attributes, custom: custom).reload
      end

      let(:old_url) { 'https://foo.bar.com/bar/foo' }

      it_behaves_like 'scc repositories'

      it('does not have a repository by the old URL') { expect(Repository.find_by(external_url: old_url)).to eq(nil) }
    end

    context 'self heals SCC repos' do
      subject(:repository) do
        service.create_repository!(product, url, attributes, custom: custom).update(scc_id: old_scc_id)
        expect(Repository.find_by(scc_id: old_scc_id)).not_to eq(nil)

        service.create_repository!(product, url, attributes, custom: custom).reload
      end

      let(:old_scc_id) { 666 }

      it_behaves_like 'scc repositories'

      it('does not have a repository by the old scc_id') { expect(Repository.find_by(scc_id: old_scc_id)).to eq(nil) }
    end

    context 'custom repo with same url' do
      subject(:repository) do
        service.create_repository!(product, url, attributes, custom: custom).update(scc_id: nil)
        service.create_repository!(product, url, attributes, custom: custom).reload
      end

      it_behaves_like 'scc repositories'
    end

    context 'custom repositories' do
      let(:product) { nil }
      let(:custom) { true }
      let(:id) { 'foo-bar' }

      it('creates the repository') { expect(repository.name).to eq('foo') }

      it('has the correct URL') { expect(repository.external_url).to eq(url) }

      it('has the correct friendly_id') { expect(repository.friendly_id).to eq('foo-bar') }

      it('is not custom') { expect(repository.custom?).to eq(true) }

      context 'already existing repositories with changing URL', :skip_sqlite do
        subject(:repository) do
          service.create_repository!(product, url, attributes, custom: custom).reload
          url = 'https://foo.bar.com/bar/foo'
          service.create_repository!(product, url, attributes, custom: custom).reload
        end

        it('raises error when the id is the same') { expect { repository }.to raise_error(/Duplicate entry/) }
      end
    end
  end

  describe '#add_product' do
    let(:repository) { create :repository }

    it('initially has no products') { expect(repository.products.count).to eq(0) }

    it 'can add a product' do
      service.attach_product!(product, repository)
      expect(repository.products.first.id).to eq(product.id)
    end
  end

  describe '#remove_product!' do
    let(:repository) { create :repository }

    before do
      service.attach_product!(product, repository)
    end

    it('initially has one products') { expect(repository.products.count).to eq(1) }

    it 'can remove a product' do
      service.detach_product!(product, repository)
      expect(repository.products.count).to eq(0)
    end
  end
end
