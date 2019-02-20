require 'rails_helper'

RSpec.describe RMT::Config do
  describe '#mirroring dedup_method' do
    context 'defaults' do
      [nil, ''].each do |dedup_method|
        before { deduplication_method(dedup_method) }
        it("defaults when supplied #{dedup_method}") { expect(described_class.deduplication_by_hardlink?).to be_truthy }
      end
    end

    context 'hardlink' do
      [:hardlink, 'hardlink'].each do |dedup_method|
        before { deduplication_method(dedup_method) }
        it("uses hardlink with #{dedup_method} as #{dedup_method.class.name}") do
          expect(described_class.deduplication_by_hardlink?).to be_truthy
        end
      end
    end

    context 'copy' do
      [:copy, 'copy'].each do |dedup_method|
        before { deduplication_method(dedup_method) }
        it("uses copy with #{dedup_method} as #{dedup_method.class.name}") do
          expect(described_class.deduplication_by_hardlink?).to be_falsey
        end
      end
    end
  end

  describe '#respond_to_missing?' do
    context 'when called with a unsupported parameter' do
      it 'returns false' do
        expect(described_class.respond_to?(:foo)).to eq(false)
      end
    end
  end

  describe '#method_missing' do
    context 'when called with a unsupported parameter' do
      it 'returns an error' do
        expect{ described_class.foo }.to raise_error(NoMethodError)
      end
    end
  end
end
