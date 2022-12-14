require 'rails_helper'

RSpec.describe RMT::Deduplicator do
  describe '#deduplicate' do
    subject(:deduplicate) do
      dummy_class.new(airgap_mode).send(:deduplicate, file)
    end

    let(:dummy_class) do
      Class.new do
        include RMT::Deduplicator
        include RMT::FileValidator

        attr_reader :airgap_mode, :deep_verify, :logger

        def initialize(airgap_mode)
          @airgap_mode = airgap_mode
          @deep_verify = false
          @logger = RMT::Logger.new('/dev/null')
        end
      end
    end

    let(:airgap_mode) { false }
    let(:dir) { Dir.mktmpdir }
    let(:dest_path) { File.join(dir, 'foo2.rpm') }
    let(:checksum_type) { 'SHA256' }
    let(:checksum) { 'c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2' }
    let(:size) { 6 }
    let(:source_path) do
      # files need to be in same filesystem for hardlinks
      file_src = file_fixture('checksum_verifier/file')
      file_dest = File.join(dir, 'foo.rpm')
      FileUtils.cp(file_src, file_dest)
      file_dest
    end

    let(:file) do
      instance_double(
        '::RMT::FileReference',
        local_path: dest_path,
        checksum: checksum,
        checksum_type: checksum_type,
        size: size
      )
    end
    let(:file_basename) { File.basename(file.local_path) }

    after do
      FileUtils.remove_entry(dir)
    end

    context 'file tracking' do
      before do
        deduplication_method(:copy)
        add_downloaded_file(file.checksum_type, file.checksum, source_path)
      end

      context 'when airgap mode is disabled' do
        let(:airgap_mode) { false }

        it 'tracks files on database' do
          deduplicate

          expect(DownloadedFile.where(local_path: dest_path).count).to eq(1)
        end
      end

      context 'when airgap mode is enabled' do
        let(:airgap_mode) { true }

        it 'does not track files on database' do
          deduplicate

          expect(DownloadedFile.where(local_path: dest_path).count).to eq(0)
        end
      end
    end

    context 'copy' do
      before do
        deduplication_method(:copy)
        add_downloaded_file(file.checksum_type, file.checksum, source_path)
      end

      context 'when there is a valid source file' do
        it 'duplicates file without hardlink' do
          expect_any_instance_of(RMT::Logger).to receive(:info)
            .with(/→ #{file_basename}/).once

          deduplicate

          expect(File.read(dest_path)).to eq(File.read(source_path))
          expect(File.stat(source_path).nlink).to eq(1)
        end
      end

      context 'when there is not a valid source file' do
        before do
          deduplication_method(:copy)
          add_downloaded_file(file.checksum_type, 'foo', source_path)
          File.open(source_path, 'a') { |f| f.puts 'this is a change' }
        end

        let(:checksum) { 'foo' }

        it('returns false') { is_expected.to be false }

        it 'does not duplicate file' do
          expect_any_instance_of(RMT::Logger).not_to receive(:info)

          deduplicate

          expect(File.exist?(dest_path)).to be false
        end

        it 'removes invalid source files' do
          deduplicate

          expect(File.exist?(source_path)).to be false
        end

        it 'untracks invalid source files' do
          expect { deduplicate }
            .to change { DownloadedFile.where(local_path: source_path).count }
            .from(1).to(0)
        end
      end
    end

    context 'hardlink' do
      context 'when there is a valid source file' do
        before do
          deduplication_method(:hardlink)
          add_downloaded_file(file.checksum_type, file.checksum, source_path)
        end

        it 'hardlinks file' do
          expect_any_instance_of(RMT::Logger).to receive(:info)
            .with(/← #{file_basename}/).once

          deduplicate

          expect(File.read(dest_path)).to eq(File.read(source_path))
          expect(File.stat(source_path).nlink).to eq(2)
        end
      end

      context 'when the system does not support hardlink' do
        before do
          deduplication_method(:hardlink)
          add_downloaded_file(file.checksum_type, file.checksum, source_path)
          allow(::FileUtils).to receive(:ln).and_raise(StandardError)
        end

        it('throws hardlink exception') do
          expect_any_instance_of(RMT::Logger).not_to receive(:info)

          expect { deduplicate }.to raise_error(::RMT::Deduplicator::HardlinkException)
        end
      end

      context 'when there is not a valid source file' do
        before do
          deduplication_method(:hardlink)
          add_downloaded_file(file.checksum_type, 'foo', source_path)
          File.open(source_path, 'a') { |f| f.puts 'this is a change' }
        end

        let(:checksum) { 'foo' }

        it('returns false') { is_expected.to be false }

        it 'does not duplicate file' do
          expect_any_instance_of(RMT::Logger).not_to receive(:info)

          deduplicate

          expect(File.exist?(dest_path)).to be false
        end

        it 'removes invalid source files' do
          deduplicate

          expect(File.exist?(source_path)).to be false
        end

        it 'untracks invalid source files' do
          expect { deduplicate }
            .to change { DownloadedFile.where(local_path: source_path).count }
            .from(1).to(0)
        end
      end
    end
  end
end
