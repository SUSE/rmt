require 'rails_helper'

RSpec.describe RMT::FileValidator do
  around do |example|
    example.run
    FileUtils.remove_entry(tmp_dir, force: true)
  end

  describe '.validate_local_file' do
    let!(:tmp_dir) { Dir.mktmpdir('rmt') }

    let(:metadata) do
      instance_double(
        '::RepomdParser::Reference',
        checksum: expected_metadata[:checksum],
        checksum_type: expected_metadata[:checksum_type],
        location: 'dummy_product/product/apples-0.1-0.x86_64.rpm',
        size: expected_metadata[:file_size]
      )
    end

    let(:file_local_path) { File.join(tmp_dir, metadata.location) }

    # File on disk shared contexts/examples

    shared_context 'file on disk' do
      before do
        fixture_path = file_fixture(metadata.location).to_s

        File.join(tmp_dir, metadata.location).tap do |file|
          FileUtils.mkdir_p(File.dirname(file))
          FileUtils.cp(fixture_path, file)
        end
      end
    end

    shared_context 'file on disk mismatches metadata' do
      include_context 'file on disk'

      let(:expected_metadata) do
        {
          checksum: '2c4e3fa1624bd23221eecdda9c7fcefad042992a9eaed227d06dd8210cfe2821',
          checksum_type: 'SHA256',
          file_size: 2020
        }
      end
    end

    shared_examples 'no files on disk' do
      it 'returns file path and invalid file status' do
        path, valid_file = described_class.validate_local_file(
          repository_dir: tmp_dir,
          metadata: metadata,
          deep_verify: deep_verify
        )

        expect(path).to eq(file_local_path)
        expect(valid_file).to be false
      end
    end

    shared_examples 'invalid file on disk' do
      it 'returns file path and invalid file status' do
        path, valid_file = described_class.validate_local_file(
          repository_dir: tmp_dir,
          metadata: metadata,
          deep_verify: deep_verify
        )

        expect(path).to eq(file_local_path)
        expect(valid_file).to be false
      end

      it 'removes the local file' do
        expect do
          described_class.validate_local_file(
            repository_dir: tmp_dir,
            metadata: metadata,
            deep_verify: deep_verify
          )
        end.to change { File.exist?(file_local_path) }.from(true).to(false)
      end
    end

    shared_examples 'valid file on disk' do
      it 'returns file path and valid file status' do
        path, valid_file = described_class.validate_local_file(
          repository_dir: tmp_dir,
          metadata: metadata,
          deep_verify: deep_verify
        )

        expect(path).to eq(file_local_path)
        expect(valid_file).to be true
      end

      it 'does not remove the local file from the disk' do
        expect do
          described_class.validate_local_file(
            repository_dir: tmp_dir,
            metadata: metadata,
            deep_verify: deep_verify
          )
        end.not_to change { File.exist?(file_local_path) == true }
      end
    end

    # File tracking on database shared contexts/examples

    shared_context 'file record on database' do
      before do
        ::DownloadedFile.track_file(
          checksum: metadata.checksum,
          checksum_type: metadata.checksum_type,
          local_path: file_local_path,
          size: metadata.size
        )
      end
    end

    shared_examples 'invalid tracked file on database' do
      it 'untracks the file in the database' do
        expect do
          described_class.validate_local_file(
            repository_dir: tmp_dir,
            metadata: metadata,
            deep_verify: deep_verify
          )
        end.to change { ::DownloadedFile.where(local_path: file_local_path).count }
          .from(1).to(0)
      end
    end

    shared_examples 'valid untracked file on disk' do
      it 'start tracking the local file in the database' do
        expect do
          described_class.validate_local_file(
            repository_dir: tmp_dir,
            metadata: metadata,
            deep_verify: deep_verify
          )
        end.to change { ::DownloadedFile.where(local_path: file_local_path).count }
          .from(0).to(1)

        file_record = ::DownloadedFile.find_by(local_path: file_local_path)

        expect(file_record).to have_attributes(
          checksum: metadata.checksum,
          checksum_type: metadata.checksum_type,
          local_path: file_local_path,
          file_size: metadata.size
        )
      end
    end

    shared_examples 'valid tracked file on disk' do
      it 'updates the database without creating a new record' do
        file_record_id = ::DownloadedFile.find_by(local_path: file_local_path).id

        expect do
          described_class.validate_local_file(
            repository_dir: tmp_dir,
            metadata: metadata,
            deep_verify: deep_verify
          )
        end.not_to change { ::DownloadedFile.where(local_path: file_local_path).count }

        updated_file_record = ::DownloadedFile.find_by(local_path: file_local_path)

        expect(updated_file_record).to have_attributes(
          id: file_record_id,
          checksum: metadata.checksum,
          checksum_type: metadata.checksum_type,
          local_path: file_local_path,
          file_size: metadata.size
        )
      end
    end

    # File and database verification

    shared_examples 'file/database integrity verification' do
      context 'no files on disk, untracked on database' do
        include_examples 'no files on disk'
      end

      context 'no files on disk, tracked on database' do
        include_context 'file record on database'

        include_examples 'no files on disk'
        include_examples 'invalid tracked file on database'
      end

      context 'invalid file on disk, untracked on database' do
        include_context 'file on disk mismatches metadata'

        include_examples 'invalid file on disk'
      end

      context 'invalid file on disk, tracked on database' do
        include_context 'file on disk mismatches metadata'
        include_context 'file record on database'

        include_examples 'invalid file on disk'
        include_examples 'invalid tracked file on database'
      end

      context 'valid file on disk, untracked on database' do
        include_context 'file on disk'

        include_examples 'valid file on disk'
        include_examples 'valid untracked file on disk'
      end

      context 'valid file on disk, tracked on database w/ valid metadata' do
        include_context 'file on disk'
        include_context 'file record on database'

        include_examples 'valid file on disk'
        include_examples 'valid tracked file on disk'
      end

      context 'valid file on disk, tracked on database w/ invalid metadata' do
        include_context 'file on disk'

        before do
          ::DownloadedFile.track_file(
            checksum: 'invalid_checksum',
            checksum_type: metadata.checksum_type,
            local_path: file_local_path,
            size: 2020
          )
        end

        include_examples 'valid file on disk'
        include_examples 'valid tracked file on disk'
      end
    end

    context 'with deep verification disabled' do
      let(:deep_verify) { false }

      # Valid file path and size, invalid checksum
      let(:expected_metadata) do
        {
          checksum: '2c4e3fa1624bd23221eecdda9c7fcefad042992a9eaed227d06dd8210cfe2821',
          checksum_type: 'SHA256',
          file_size: 1934
        }
      end

      include_examples 'file/database integrity verification'
    end

    context 'with deep verification enabled' do
      let(:deep_verify) { true }

      # Valid file path, size and checksum
      let(:expected_metadata) do
        {
          checksum: '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851',
          checksum_type: 'SHA256',
          file_size: 1934
        }
      end

      include_examples 'file/database integrity verification'
    end
  end
end
