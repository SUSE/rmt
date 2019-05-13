require 'rails_helper'

describe RepositoryService do
  subject(:service) { described_class.new }

  let(:product) { create :product, :with_service }
  let(:custom_repository) { create :repository, :custom }
  let(:suse_repository) { create :repository }

  describe '#create_repository' do
    before do
      service.create_repository!(product, 'http://foo.bar/repos', {
        name: 'foo',
        mirroring_enabled: true,
        description: 'foo',
        autorefresh: true,
        enabled: false
      })
    end

    it('creates the repository') { expect(Repository.find_by(external_url: 'http://foo.bar/repos').name).to eq('foo') }
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
