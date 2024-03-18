class RMT::Downloader::Stats
  attr_reader :total_size, :files_count, :total_size_in_mb

  def initialize
    @total_size_mutex = Mutex.new
    @files_count_mutex = Mutex.new
    @total_size = 0
    @files_count = 0
  end

  def increment_files_count
    @files_count_mutex.synchronize do
      @files_count += 1
    end
  end

  def increment_total_size(bytes)
    @total_size_mutex.synchronize do
      @total_size += bytes
    end
  end

  def reset!
    @total_size = 0
    @files_count = 0
  end

  def to_h
    {
      files_count: files_count,
      total_size: total_size
    }
  end
end
