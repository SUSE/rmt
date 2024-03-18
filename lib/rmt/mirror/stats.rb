require 'forwardable'

class RMT::Mirror::Stats
  attr_reader :mirrored_repos_count, :download_stats

  extend Forwardable

  def initialize(download_stats: RMT::Downloader::Stats.new)
    @download_stats = download_stats
    reset!
  end

  def_delegators :download_stats, :total_size_in_mb, :files_count

  def reset!
    @mirrored_repos_count = 0
    # Timing it here isnt perfecct, but since its running on CLI it would not make that much of a differance
    @start_time = Time.now.to_i

    # TODO: revist this, should we be calling it here or not ?
    download_stats.reset!
  end

  def increment_mirrored_repos_count
    @mirrored_repos_count += 1
  end

  def elapsed_seconds
    elapsed = Time.now.to_i - @start_time
    elapsed.round
  end
end
