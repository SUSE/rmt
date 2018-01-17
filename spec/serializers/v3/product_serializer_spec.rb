require 'rails_helper'

describe V3::ProductSerializer do
  let(:sled15) { create(:product, name: 'SLED') }
  let(:sles15) { create(:product, name: 'SLES') }
  let!(:basesystem) do
    create(:product, :extension, name: 'BASESYSTEM', base_products: [sles15, sled15], recommended: true)
  end
  let!(:server_applications) do
    create(:product, :extension, name: 'SERVER APPLICATIONS', base_products: [basesystem], root_product: sles15)
  end
  let(:base_url) { 'http://example.com' }

  describe 'SLES extension tree' do
    subject(:serializer) { described_class.new(sles15, root_product: sles15, base_url: base_url) }

    let(:top_extension) { serializer.as_json[:extensions].first }
    let(:nested_extension) { top_extension[:extensions].first }

    it 'has base system extension' do
      expect(top_extension[:name]).to eq(basesystem.name)
    end

    it 'has base system and it is recommended' do
      expect(top_extension[:recommended]).to eq(true)
    end

    it 'has server applications extension' do
      expect(nested_extension[:name]).to eq(server_applications.name)
    end

    it 'has server applications extension and it is not recommended' do
      expect(nested_extension[:recommended]).to eq(false)
    end
  end

  describe 'SLED extension tree' do
    subject(:serializer) { described_class.new(sled15, root_product: sled15, base_url: base_url) }

    let(:top_extension) { serializer.as_json[:extensions].first }
    let(:nested_extension) { top_extension[:extensions].first }

    it 'has base system extension' do
      expect(top_extension[:name]).to eq(basesystem.name)
    end

    it 'has base system and it is recommended' do
      expect(top_extension[:recommended]).to eq(true)
    end

    it 'has no nested extensions' do
      expect(nested_extension).to be_nil
    end
  end
end
