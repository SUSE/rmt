require 'rails_helper'

RSpec.describe ProductService do
  subject(:product_service) { described_class.new }

  let(:product) { create :product }
  let(:product_with_service) { create :product, :with_mirrored_repositories }

  describe '#get_service' do
    before do
      expect(product.service).to be_nil
      expect(product_with_service.service).not_to be_nil
    end

    it('gets service from product with service') { expect(product_service.get_service(product_with_service)).to eq(product_with_service.service) }
    it('creates a service for product') { expect(product_service.get_service(product).product_id).to eq(product.id) }
  end
end
