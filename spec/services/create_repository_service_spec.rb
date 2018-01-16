require 'rails_helper'

describe CreateRepositoryService do
  subject(:service) { described_class.new }

  let(:product) { create :product }
  let(:custom_repository) { create :repository, :custom }
  let(:suse_repository) { create :repository }

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

    it('creates the repository') { expect(Repository.by_url('http://foo.bar/repos').name).to eq('foo') }

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
      end.to raise_error(CreateRepositoryService::InvalidExternalUrl)
    end
  end
end
