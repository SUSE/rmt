require 'rspec'
require 'rails_helper'

RSpec.describe RMT::Mirror::Stats do
  subject(stats) { described_class.new }

  describe '#initialize' do
    context 'with default arguments' do
      it 'creates a new download_stats object of type RMT::Downloader::Stats' do
        expect(stats.download_stats).to be_a(RMT::Downloader::Stats)
      end
    end
  end

  describe '#def_delegators' do
    it 'delegates total_size_in_mb to download_stats' do
      expect(stats).to delegate_method(:total_size_in_mb).to(:download_stats)
    end

    it 'delegates files_count to download_stats' do
      expect(stats).to delegate_method(:files_count).to(:download_stats)
    end
  end

  describe '#reset!' do
    before do
      stats.increment_mirrored_repos_count
    end

    it 'resets mirrored_repos_count to 0' do
      expect { stats.reset! }.to change(stats, :mirrored_repos_count).to(0)
    end

    it 'resets download_stats' do
      expect(stats.download_stats).to receive(:reset!)
      stats.reset!
    end
  end

  describe '#increment_mirrored_repos_count' do
    it 'increments mirrored_repos_count by 1' do
      expect { stats.increment_mirrored_repos_count }.to change(stats, :mirrored_repos_count).by(1)
    end
  end

  describe '#elapsed_seconds' do
    after { Timecop.return }

    it 'calculates the elapsed time since start_time rounded to seconds' do
      stats.reset!
      Timecop.travel 10.seconds.from_now
      expect(stats.elapsed_seconds).to eq(10)
    end
  end
end
