# rubocop:disable RSpec/ExpectOutput

RSpec.shared_context 'console output' do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  around do |example|
    $stdout = stdout.reopen('')
    $stderr = stderr.reopen('')
    example.run
    $stdout = STDOUT
    $stderr = STDERR
  end
end
