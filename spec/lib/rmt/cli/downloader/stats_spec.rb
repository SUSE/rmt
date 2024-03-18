require 'rspec'
require 'rails_helper'

RSpec.describe RMT::Downloader::Stats do
  subject { described_class.new }

  describe '#initialize' do
    it 'initializes files_count to 0' do
      expect(subject.files_count).to eq(0)
    end

    it 'initializes total_size to 0' do
      expect(subject.total_size).to eq(0)
    end
  end

  describe '#increment_files_count' do
    it 'increments files_count by 1' do
      expect { subject.increment_files_count }.to change(subject, :files_count).by(1)
    end

    it 'uses a mutex to synchronize access' do
      expect(subject.instance_variable_get(:@files_count_mutex)).to receive(:synchronize)
      subject.increment_files_count
    end
  end

  describe '#increment_total_size' do
    let(:size) { 1024 }

    it 'increments total_size by the provided size' do
      expect { subject.increment_total_size(size) }.to change(subject, :total_size).by(size)
    end

    it 'uses a mutex to synchronize access' do
      expect(subject.instance_variable_get(:@total_size_mutex)).to receive(:synchronize)
      subject.increment_total_size(size)
    end
  end

  describe '#reset!' do
    before do
      subject.increment_files_count
      subject.increment_total_size(1024)
    end

    it 'resets total_size and files_count to 0' do
      expect { subject.reset! }.to change(subject, :total_size).to(0)
        .and(change(subject, :files_count).to(0))
    end
  end

  describe '#total_size_in_mb' do
    context 'with total size of 0' do
      it 'returns 0.0' do
        expect(subject.total_size_in_mb).to eq(0.0)
      end
    end

    context 'with total size greater than 0' do
      let(:size) { 1_000_000 } # 1 MB

      before { subject.increment_total_size(size) }

      it 'returns the total size in megabytes rounded to 2 decimal places' do
        expect(subject.total_size_in_mb).to eq(1.00)
      end
    end
  end

  describe '#to_h' do
    before do
      subject.increment_files_count
      subject.increment_total_size(1024)
    end

    it 'returns a hash with files_count and total_size keys' do
      expect(subject.to_h).to eq(
        files_count: subject.files_count,
        total_size: subject.total_size
      )
    end
  end
end
