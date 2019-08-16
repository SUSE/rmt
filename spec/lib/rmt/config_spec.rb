require 'rails_helper'

RSpec.describe RMT::Config do
  describe '#mirroring mirror_src' do
    context 'defaults' do
      [nil, ''].each do |config_provided|
        before { Settings['mirroring'].mirror_src = config_provided }
        it("defaults when supplied #{config_provided}") { expect(described_class.mirror_src_files?).to be_falsey }
      end
    end

    context 'true' do
      [true, 'true'].each do |config_provided|
        before { Settings['mirroring'].mirror_src = config_provided }
        it("defaults when supplied #{config_provided}") { expect(described_class.mirror_src_files?).to be_truthy }
      end
    end

    context 'false' do
      [false, 'false'].each do |config_provided|
        before { Settings['mirroring'].mirror_src = config_provided }
        it("defaults when supplied #{config_provided}") { expect(described_class.mirror_src_files?).to be_falsey }
      end
    end
  end

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
