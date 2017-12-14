require 'rails_helper'

RSpec.describe RMT::FileUtils do
  describe '#deduplicate' do
    let(:dir) { Dir.mktmpdir }
    let(:dest_path) { File.join(dir, 'foo2.rpm') }
    let(:checksum_type) { 'SHA256' }
    let(:checksum) { 'c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2' }
    let(:source_path) do
      # files need to be in same filesystem for hardlinks
      file_src = fixture_file_path('checksum_verifier/file')
      file_dest = File.join(dir, 'foo.rpm')
      FileUtils.cp(file_src, file_dest)
      file_dest
    end

    after do
      FileUtils.remove_entry(dir)
    end

    context 'copy' do
      before do
        deduplication_method(:copy)
        DownloadedFile.add_file!(checksum_type, checksum, source_path)
        described_class.deduplicate(checksum_type, checksum, dest_path)
      end

      it('duplicates file') { expect(File.read(dest_path)).to eq(File.read(source_path)) }
      it('duplicated file with copy') { expect(File.stat(source_path).nlink).to eq(1) }
    end

    context 'copy with changed file' do
      before do
        deduplication_method(:copy)
        DownloadedFile.add_file!(checksum_type, 'foo', source_path)
        open(source_path, 'a') { |f| f.puts 'this is a change' }
        described_class.deduplicate(checksum_type, 'foo', dest_path)
      end

      it('duplicates file') { expect(File.exist?(dest_path)).to be_falsey }
      it('source is not linked') { expect(File.stat(source_path).nlink).to eq(1) }
    end

    context 'hardlink with proper checksum' do
      before do
        deduplication_method(:hardlink)
        DownloadedFile.add_file!(checksum_type, checksum, source_path)
        described_class.deduplicate(checksum_type, checksum, dest_path)
      end

      it('duplicates file') { expect(File.read(dest_path)).to eq(File.read(source_path)) }
      it('duplicated file with copy') { expect(File.stat(source_path).nlink).to eq(2) }
    end


    context 'hardlink with changed file' do
      before do
        deduplication_method(:hardlink)
        DownloadedFile.add_file!(checksum_type, 'foo', source_path)
        open(source_path, 'a') { |f| f.puts 'this is a change' }
        described_class.deduplicate(checksum_type, 'foo', dest_path)
      end

      it('duplicates file') { expect(File.exist?(dest_path)).to be_falsey }
      it('source is not linked') { expect(File.stat(source_path).nlink).to eq(1) }
    end
  end
end
