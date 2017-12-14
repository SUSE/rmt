require 'spec_helper'
require 'rails_helper'


describe DownloadedFile, type: :model do
  describe '#add_file!' do
    let(:test_file_1_path) { fixture_file_path('dummy_product/product/apples-0.1-0.x86_64.rpm') }
    let(:test_file_2_path) { fixture_file_path('dummy_product/product/apples-0.2-0.x86_64.rpm') }

    before do
      DownloadedFile.add_file!('foo', 'bar', test_file_1_path)
      DownloadedFile.add_file!('foobar', 'barfoo', test_file_2_path)
    end

    it 'has file1' do
      expect(DownloadedFile.find_by(checksum_type: 'foo', checksum: 'bar').local_path).to eq(test_file_1_path)
    end

    it 'has file2' do
      expect(DownloadedFile.find_by(checksum_type: 'foobar', checksum: 'barfoo').local_path).to eq(test_file_2_path)
    end

    it 'handles duplicates' do
      DownloadedFile.add_file!('foo', 'bar', test_file_2_path)
      expect(DownloadedFile.find_by(checksum_type: 'foo', checksum: 'bar').local_path).to eq(test_file_1_path)
    end
  end

  describe '#get_local_path_by_checksum' do
    let(:checksum_type) { 'SHA256' }
    let(:checksum) { '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851' }
    let(:test_file_path) { fixture_file_path('dummy_product/product/apples-0.1-0.x86_64.rpm') }
    let(:test_file_2_path) { fixture_file_path('dummy_product/product/apples-0.2-0.x86_64.rpm') }

    it 'gets the correct path with proper checksum' do
      DownloadedFile.add_file!(checksum_type, checksum, test_file_path)
      expect(DownloadedFile.get_local_path_by_checksum(checksum_type, checksum)).to eq(test_file_path)
    end

    it 'returns nil if files has been changed' do
      DownloadedFile.add_file!(checksum_type, checksum, test_file_path)
      file = DownloadedFile.find_by(checksum_type: checksum_type, checksum: checksum)
      file.update(local_path: test_file_2_path)
      expect(DownloadedFile.get_local_path_by_checksum(checksum_type, 'foo')).to be_nil
    end

    it 'handles missing files' do
      DownloadedFile.add_file!(checksum_type, checksum, '/foo/bar')
      expect(DownloadedFile.get_local_path_by_checksum(checksum_type, checksum)).to be_nil
    end
  end
end
