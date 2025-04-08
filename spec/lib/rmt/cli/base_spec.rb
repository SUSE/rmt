require 'rails_helper'

RSpec.describe RMT::CLI::Base do
  subject(:base) { described_class.new }


  describe '#needs_path' do
    before do
      # Make all protected methods public for testing purpose
      described_class.send(:public, :needs_path)
    end

    let(:test_paths) do
      [
        { path: '/foo/bar', expected: '/foo/bar' },
        { path: '/foo/bar/test/..', expected: '/foo/bar' },
        { path: '/foo/./bar', expected: '/foo/bar' }
      ]
    end

    it 'returns a normalised path' do
      allow(File).to receive(:directory?).and_return(true)
      test_paths.each do |test_case|
        expect(base.needs_path(test_case[:path])).to eq(test_case[:expected])
      end
    end

    it 'raises an exception if the path is not writeable' do
      allow(File).to receive(:directory?).and_return(true)
      allow(File).to receive(:writable?).and_return(false)

      expect { base.needs_path('/foo/bar', writable: true) }.to raise_error(RMT::CLI::Error, %r{/foo/bar is not writable by user})
    end

    it 'raises an exception if the file is not a directory' do
      allow(File).to receive(:directory?).and_return(false)

      expect { base.needs_path('/foo/bar') }.to raise_error(RMT::CLI::Error, %r{/foo/bar is not a directory})
    end
  end
end
