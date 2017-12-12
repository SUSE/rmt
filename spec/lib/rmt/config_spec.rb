require 'rails_helper'

RSpec.describe RMT::Config do
  describe '#mirroring dedup_method' do
    context 'handles nil' do
      before { deduplication_method(nil) }
      it('defaults to hardlink') { expect(described_class.deduplication_by_hardlink?).to be_truthy }
    end

    context 'handles empty string' do
      before { deduplication_method('') }
      it('defaults to hardlink') { expect(described_class.deduplication_by_hardlink?).to be_truthy }
    end

    context 'handles everything' do
      before { deduplication_method(Class.new) }
      it('defaults to hardlink') { expect(described_class.deduplication_by_hardlink?).to be_truthy }
    end

    context 'handles copy as string' do
      before { deduplication_method('copy') }
      it('defaults to hardlink') { expect(described_class.deduplication_by_hardlink?).to be_falsey }
    end

    context 'handles copy as symbol' do
      before { deduplication_method(:copy) }
      it('defaults to hardlink') { expect(described_class.deduplication_by_hardlink?).to be_falsey }
    end

    context 'handles hardlink as string' do
      before { deduplication_method('hardlink') }
      it('defaults to hardlink') { expect(described_class.deduplication_by_hardlink?).to be_truthy }
    end

    context 'handles hardlink as symbol' do
      before { deduplication_method(:hardlink) }
      it('defaults to hardlink') { expect(described_class.deduplication_by_hardlink?).to be_truthy }
    end
  end
end
