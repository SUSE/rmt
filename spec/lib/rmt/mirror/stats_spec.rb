require 'rspec'
require 'rails_helper'

RSpec.describe RMT::Mirror::Stats do
  subject { described_class.new }

  describe '#initialize' do
    context 'with default arguments' do
      it 'creates a new download_stats object of type RMT::Downloader::Stats' do
        expect(subject.download_stats).to be_a(RMT::Downloader::Stats)
      end
    end
  end

  describe '#def_delegators' do
    it 'delegates total_size_in_mb to download_stats' do
      expect(subject).to delegate_method(:total_size_in_mb).to(:download_stats)
    end

    it 'delegates files_count to download_stats' do
      expect(subject).to delegate_method(:files_count).to(:download_stats)
    end
  end

  describe '#reset!' do
    before do
      subject.increment_mirrored_repos_count
    end

    it 'resets mirrored_repos_count to 0' do
      expect { subject.reset! }.to change(subject, :mirrored_repos_count).to(0)
    end

    it 'resets download_stats' do
      expect(subject.download_stats).to receive(:reset!)
      subject.reset!
    end
  end

  describe '#increment_mirrored_repos_count' do
    it 'increments mirrored_repos_count by 1' do
      expect { subject.increment_mirrored_repos_count }.to change(subject, :mirrored_repos_count).by(1)
    end
  end

  describe '#elapsed_seconds' do
    after { Timecop.return }

    it 'calculates the elapsed time since start_time rounded to seconds' do
      subject.reset!
      Timecop.travel 10.seconds.from_now
      expect(subject.elapsed_seconds).to eq(10)
    end
  end
end
