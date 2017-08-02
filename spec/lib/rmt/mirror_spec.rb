require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::Mirror do

  let(:downloader_double) { double 'RMT::Downloader double' }
  let(:repomd_double) { double 'RMT::Rpm::RepomdXmlParser double' }
  let(:primaryxml_double) { double 'RMT::Rpm::PrimaryXmlParser double' }
  let(:deltainfoxml_double) { double 'RMT::Rpm::DeltainfoXmlParser double' }
  let(:referenced_metadata) do
    [
      RMT::Rpm::FileEntry.new('repodata/primary.xml', 'SHA256', 'dummy_checksum_1', :primary),
      RMT::Rpm::FileEntry.new('repodata/deltainfo.xml', 'SHA256', 'dummy_checksum_2', :deltainfo),
    ]
  end
  let(:referenced_rpms) { [ RMT::Rpm::FileEntry.new('dummy.rpm', 'SHA256', 'dummy_checksum_3', :rpm) ] }
  let(:referenced_drpms) { [ RMT::Rpm::FileEntry.new('dummy.drpm', 'SHA256', 'dummy_checksum_4', :drpm) ] }

  describe '#mirror' do
    it 'mirrors metadata and data' do
      expect(RMT::Downloader).to receive(:new) do |args|
        FileUtils.mkpath(File.join(args[:local_path], 'repodata'))
        downloader_double
      end

      expect(downloader_double).to receive(:download).with('repodata/repomd.xml').and_return('temp_md_1').once
      expect(downloader_double).to receive(:download).with('repodata/repomd.xml.key').and_return('temp_md_2').once
      expect(downloader_double).to receive(:download).with('repodata/repomd.xml.asc').and_return('temp_md_3').once

      expect(downloader_double).to receive(:local_path=).once

      expect(RMT::Rpm::RepomdXmlParser).to receive(:new).and_return(repomd_double).once
      expect(repomd_double).to receive(:parse)
      expect(repomd_double).to receive(:referenced_files).and_return(referenced_metadata)

      expect(downloader_double).to receive(:download).with(
        'repodata/primary.xml', 'SHA256', 'dummy_checksum_1'
      ).and_return('temp_md_4').once

      expect(downloader_double).to receive(:download).with(
        'repodata/deltainfo.xml', 'SHA256', 'dummy_checksum_2'
      ).and_return('temp_md_5').once

      expect(RMT::Rpm::PrimaryXmlParser).to receive(:new).and_return(primaryxml_double).once
      expect(primaryxml_double).to receive(:parse).once
      expect(primaryxml_double).to receive(:referenced_files).and_return(referenced_rpms).once

      expect(RMT::Rpm::DeltainfoXmlParser).to receive(:new).and_return(deltainfoxml_double).once
      expect(deltainfoxml_double).to receive(:parse).once
      expect(deltainfoxml_double).to receive(:referenced_files).and_return(referenced_drpms).once

      expect(downloader_double).to receive(:download_multi).with(referenced_rpms).and_return('temp_rpm').once
      expect(downloader_double).to receive(:download_multi).with(referenced_drpms).and_return('temp_drpm').once

      described_class.new(
        mirroring_base_dir: Dir.tmpdir,
        repository_url: 'http://example.com/repo/',
        local_path: '/repo',
        mirror_src: false
      ).mirror
    end
  end
end
