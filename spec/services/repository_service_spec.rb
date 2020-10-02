require 'rails_helper'

describe RepositoryService do
  subject(:service) { described_class.new }

  let(:product) { create :product, :with_service }
  let(:custom_repository) { create :repository, :custom }
  let(:suse_repository) { create :repository }

  describe '#create_repository' do
    let(:attributes) do
      {
        name: 'foo',
        mirroring_enabled: true,
        description: 'foo',
        autorefresh: true,
        enabled: false,
        id: 50
      }
    end

    context 'scc repositories' do
      before do
        service.create_repository!(product, 'http://foo.bar/repos', attributes)
      end

      it('creates the repository') { expect(Repository.find_by(external_url: 'http://foo.bar/repos').name).to eq('foo') }

      it('has the correct friendly_id') { expect(Repository.find_by(external_url: 'http://foo.bar/repos').friendly_id).to eq('50') }
    end

    context 'custom repositories' do
      before do
        service.create_repository!(nil, 'http://foo.bar/repos', attributes, custom: true)
      end

      it('creates the repository') { expect(Repository.find_by(external_url: 'http://foo.bar/repos').name).to eq('foo') }

      it('has the correct friendly_id') { expect(Repository.find_by(external_url: 'http://foo.bar/repos').friendly_id).to eq('50') }
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
