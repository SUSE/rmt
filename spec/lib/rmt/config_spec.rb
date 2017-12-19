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
end
