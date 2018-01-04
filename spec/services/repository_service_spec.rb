require 'rails_helper'

RSpec.describe RepositoryService do
  subject(:service) { described_class.new }

  let(:product) { create :product }
  let(:custom_repository) { create :repository, is_custom: true }
  let(:suse_repository) { create :repository }

  describe '#repository_by_id' do
    it('finds the repository by id') { expect(service.repository_by_id(custom_repository.id)).to eq(custom_repository) }
    it('does not find repository by wrong id') { expect(service.repository_by_id('foo')).not_to eq(custom_repository) }
  end

  describe '#repository_by_url' do
    it('finds the repository by url') { expect(service.repository_by_url(custom_repository.external_url)).to eq(custom_repository) }
    it('finds the repository by wrong url') { expect(service.repository_by_url('http://foo.bar')).not_to eq(custom_repository) }
  end

  describe '#create_repository' do
    before do
      product_service = Service.find_or_create_by(product_id: product.id)
      service.create_repository(product_service, 'http://foo.bar/repos', {
        name: 'foo',
        mirroring_enabled: true,
        description: 'foo',
        autorefresh: 1,
        enabled: 0
      })
    end

    it('creates the repository') { expect(service.repository_by_url('http://foo.bar/repos').name).to eq('foo') }

    it 'returns error on invalid repository url' do
      product_service = Service.find_or_create_by(product_id: product.id)
      expect do
        service.create_repository(product_service, 'http://foo.bar', {
          name: 'foo',
          mirroring_enabled: true,
          description: 'foo',
          autorefresh: 1,
          enabled: 0
        })
      end.to raise_error(RepositoryService::InvalidExternalUrl)
    end
  end

  describe '#remove_repository' do
    it('has custom repository') { expect(Repository.find_by(id: custom_repository.id)).not_to be_nil }
    it('removes custom repositories') do
      service.remove_repository(custom_repository)
      expect(Repository.find_by(id: custom_repository.id)).to be_nil
    end

    it('has non-custom repository') { expect(Repository.find_by(id: suse_repository.id)).not_to be_nil }
    it('does not remove non-custom repositories') do
      service.remove_repository(suse_repository)
      expect(Repository.find_by(id: suse_repository.id)).not_to be_nil
    end
  end
end
