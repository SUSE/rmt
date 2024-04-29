# rubocop:disable RSpec/ExpectOutput

RSpec.configure do |c|
  c.around(:each) do |example|
    original_stdout = $stdout
    original_stderr = $stderr

    buffers = { stdout: StringIO.new, stderr: StringIO.new }

    $stdout = buffers[:stdout]
    $stderr = buffers[:stderr]
    example.run
    $stdout = original_stdout
    $stderr = original_stderr

    buffers.each do |stream_name, buffer|
      if buffer.size > 0 # rubocop:disable Style/ZeroLengthPredicate -- there's no .empty? method on StringIO object
        puts
        puts "It seems that you specs output something to #{stream_name}:"
        buffer.rewind
        buffer.each_line { |l| puts l }
        puts
        puts "Please make sure that your specs don't make a mess in the console."
        puts 'Only you can prevent forest fires!'
        raise "Messy #{stream_name}"
      end
    end
  end
end
