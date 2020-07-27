require 'spec_helper'
require 'rails_helper'


describe DownloadedFile, type: :model do
  describe '#valid_local_file?' do
    around do |example|
      @tmp_dir = Dir.mktmpdir('rmt')
      example.run
      FileUtils.remove_entry(@tmp_dir)
    end

    let(:checksum_type) { 'SHA256' }
    let(:checksum) { '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851' }
    let(:test_file_path) do
      fixture_relative_path = 'dummy_product/product/apples-0.1-0.x86_64.rpm'
      fixture_path = file_fixture(fixture_relative_path).to_s

      File.join(@tmp_dir, fixture_relative_path).tap do |file|
        FileUtils.mkdir_p(File.dirname(file))
        FileUtils.cp(fixture_path, file)
      end
    end

    it 'returns true if the file is valid' do
      add_downloaded_file(checksum_type, checksum, test_file_path)
      expect(DownloadedFile.valid_local_file?(checksum_type, checksum, test_file_path)).to be(true)
    end

    it 'returns false for invalid files' do
      add_downloaded_file(checksum_type, checksum, test_file_path)
      expect(DownloadedFile.valid_local_file?(checksum_type, checksum.sub('5', '2'), test_file_path)).to be(false)
    end

    it 'returns false when file does not exist yet' do
      expect(DownloadedFile.valid_local_file?(checksum_type, checksum, 'foo.rpm')).to be(false)
    end

    it 'tracks the file again if not yet tracked' do
      response = nil
      expect { response = DownloadedFile.valid_local_file?(checksum_type, checksum, test_file_path) }
        .to change { DownloadedFile.where(local_path: test_file_path).count }
        .from(0).to(1)

      expect(response).to be true
    end

    context 'when a file matches a DB entry but not the checksum metadata' do
      it 'stops tracking and remove invalid files' do
        add_downloaded_file(checksum_type, checksum, test_file_path)

        expect(DownloadedFile.where(local_path: test_file_path).count).to eq(1)
        expect(File.exist?(test_file_path)).to be(true)

        expect(DownloadedFile.valid_local_file?(checksum_type, checksum.sub('5', '2'), test_file_path)).to be(false)

        expect(DownloadedFile.where(local_path: test_file_path).count).to eq(0)
        expect(File.exist?(test_file_path)).to be(false)
      end
    end
  end

  describe '#get_local_path_by_checksum' do
    let(:checksum_type) { 'SHA256' }
    let(:checksum) { '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851' }
    let(:test_file_path) { file_fixture('dummy_product/product/apples-0.1-0.x86_64.rpm').to_s }
    let(:test_file_2_path) { file_fixture('dummy_product/product/apples-0.2-0.x86_64.rpm').to_s }

    it 'gets the correct path with proper checksum' do
      add_downloaded_file(checksum_type, checksum, test_file_path)

      file = DownloadedFile.get_local_path_by_checksum(checksum_type, checksum)

      expect(file.local_path).to eq(test_file_path)
    end

    it 'returns nil if files has been changed' do
      add_downloaded_file(checksum_type, checksum, test_file_path)
      file = DownloadedFile.find_by(checksum_type: checksum_type, checksum: checksum)
      file.update(local_path: test_file_2_path)
      expect(DownloadedFile.get_local_path_by_checksum(checksum_type, 'foo')).to be_nil
    end

    it 'handles missing files' do
      add_downloaded_file(checksum_type, checksum, '/foo/bar')
      expect(DownloadedFile.get_local_path_by_checksum(checksum_type, checksum)).to be_nil
    end
  end

  describe '#track_file' do
    let(:test_file) { file_fixture('dummy_product/product/apples-0.1-0.x86_64.rpm').to_s }
    let(:file_attributes) do
      {
        checksum_type: 'SHA256',
        checksum: '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851',
        local_path: test_file,
        size: 1934
      }
    end

    context 'when there are no records with the specified local path' do
      it 'creates a new record' do
        expect { described_class.track_file(file_attributes) }
          .to change { described_class.count }.by(1)

        expect(described_class.find_by(local_path: file_attributes[:local_path]))
          .to have_attributes(checksum_type: file_attributes[:checksum_type],
                              checksum: file_attributes[:checksum],
                              local_path: file_attributes[:local_path],
                              file_size: file_attributes[:size])
      end
    end

    context 'when there is a record with the specified local path' do
      before do
        described_class.create(
          checksum_type: file_attributes[:checksum_type],
          checksum: file_attributes[:checksum],
          local_path: file_attributes[:local_path],
          file_size: file_attributes[:size]
        )
      end

      context 'and the file attributes match the existent record' do
        it 'returns the existent record' do
          existent_record = described_class.find_by(local_path: file_attributes[:local_path])

          response = nil
          expect { response = described_class.track_file(file_attributes) }
            .not_to change { described_class.count }
          expect(response).to be true

          expect(described_class.find_by(local_path: file_attributes[:local_path]))
            .to eq(existent_record)
        end
      end

      context 'and the file attributes do not match the existent record' do
        it 'updates and then returns the existent record' do
          existent_record = described_class.find_by(local_path: file_attributes[:local_path])
          updated_file_attributes = file_attributes.merge(size: 2020)

          response = nil
          expect { response = described_class.track_file(updated_file_attributes) }
            .not_to change { described_class.count }
          expect(response).to be true

          expect(described_class.find_by(local_path: file_attributes[:local_path]))
            .to have_attributes(id: existent_record.id,
                                checksum_type: updated_file_attributes[:checksum_type],
                                checksum: updated_file_attributes[:checksum],
                                local_path: file_attributes[:local_path],
                                file_size: updated_file_attributes[:size])
        end
      end

      it 'allows checksum duplicated records' do
        duplicated_file_attributes = file_attributes
          .merge(local_path: test_file.sub('apples', 'oranges'))

        described_class.track_file(file_attributes)
        described_class.track_file(duplicated_file_attributes)

        files_with_duplicated_checksum = described_class.where(
          checksum: file_attributes[:checksum],
          checksum_type: file_attributes[:checksum_type]
        )

        expect(files_with_duplicated_checksum.count).to eq(2)
      end
    end
  end

  describe '#untrack_file' do
    let(:test_file) { file_fixture('dummy_product/product/apples-0.1-0.x86_64.rpm').to_s }

    context 'when there are no records with the specified local path' do
      it 'does not raise any errors' do
        described_class.where(local_path: test_file).destroy_all

        expect { described_class.untrack_file(test_file) }.not_to raise_error
      end
    end

    context 'when there are records with the specified local path' do
      before do
        described_class.create(
          checksum_type: 'SHA256',
          checksum: '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851',
          local_path: test_file,
          file_size: 1934
        )
      end

      it 'deletes the database records' do
        described_class.untrack_file(test_file)

        expect(described_class.where(local_path: test_file).count).to eq(0)
      end
    end
  end
end
