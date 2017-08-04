require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::Mirror do
  describe '#mirror' do
    let(:rmt_mirror) do
      described_class.new(
        mirroring_base_dir: @tmp_dir,
        repository_url: 'http://localhost/dummy_repo/',
        local_path: '/dummy_repo',
        mirror_src: false
      )
    end

    before do
      @tmp_dir = Dir.mktmpdir('rmt')

      # The cassette can be recorded with :typhoeus vcr adapter from this pull request:
      # https://github.com/vcr/vcr/pull/656
      # However it can be played back only by :webmock vcr adapter :-)
      VCR.use_cassette 'mirroring' do
        rmt_mirror.mirror
      end
    end
    after { FileUtils.remove_entry(@tmp_dir) }

    it 'downloads rpm files' do
      rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.rpm$/ }
      expect(rpm_entries.length).to eq(4)
    end

    it 'downloads drpm files' do
      rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.drpm$/ }
      expect(rpm_entries.length).to eq(2)
    end
  end
end
