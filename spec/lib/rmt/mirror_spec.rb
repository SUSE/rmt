require 'rails_helper'

RSpec.describe RMT::Mirror do
  describe '#mirror' do
    context 'without auth_token' do
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

    context 'with auth_token' do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          repository_url: 'http://localhost/dummy_repo/',
          local_path: '/dummy_repo',
          auth_token: 'repo_auth_token',
          mirror_src: false
        )
      end

      before do
        @tmp_dir = Dir.mktmpdir('rmt')

        VCR.use_cassette 'mirroring_with_auth_token' do
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
end
