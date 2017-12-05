require 'rails_helper'

describe RMT::CLI::Import do
  let(:path) { '/mnt/usb' }

  describe 'data' do
    it 'calls sync with special params' do
      expect_any_instance_of(RMT::SCC).to receive(:import).with(path)
      described_class.start(['data', path])
    end
  end

  # describe 'repos' do
  #   it 'mirrors enabled repos from path' do
  #     expect(RMT::Mirror).to receive(:new)
  #     described_class.start(['repos', path])
  #   end
  # end
end
