shared_examples 'handles non-existing path' do
  context 'with non-existing path' do
    it 'complains and exits' do
      FakeFS.with_fresh do
        expect { command }.to output("#{path} is not a directory.\n").to_stderr
      end
    end
  end
end
