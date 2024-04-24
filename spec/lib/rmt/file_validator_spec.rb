require 'rails_helper'

RSpec.describe RMT::FileValidator do
  around do |example|
    example.run
    FileUtils.remove_entry(tmp_dir, force: true)
  end

  let!(:tmp_dir) { Dir.mktmpdir('rmt') }
  let(:dummy_class) do
    Class.new do
      include RMT::FileValidator

      attr_reader :deep_verify

      def initialize(deep_verify)
        @deep_verify = deep_verify
      end
    end
  end

  describe '#validate_local_file' do
    let(:file_relative_remote_path) { 'dummy_product/product/apples-0.1-0.x86_64.rpm' }
    let(:file_local_path) { File.join(tmp_dir, file_relative_remote_path) }

    let(:file) do
      instance_double(
        '::RMT::FileReference',
        local_path: file_local_path,
        checksum: expected_metadata[:checksum],
        checksum_type: expected_metadata[:checksum_type],
        size: expected_metadata[:file_size]
      )
    end

    # File on disk shared contexts/examples

    shared_context 'file on disk' do
      before do
        fixture_path = file_fixture(file_relative_remote_path).to_s

        file.local_path.tap do |file|
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
      it 'returns invalid file status' do
        is_expected.to be false
      end
    end

    shared_examples 'invalid file on disk' do
      it 'returns invalid file status' do
        is_expected.to be false
      end

      it 'removes the local file' do
        expect { validate_local_file }
          .to change { File.exist?(file.local_path) }.from(true).to(false)
      end
    end

    shared_examples 'valid file on disk' do
      it 'returns valid file status' do
        is_expected.to be true
      end

      it 'does not remove the local file from the disk' do
        expect { validate_local_file }
          .not_to change { File.exist?(file.local_path) == true }
      end
    end

    # File tracking on database shared contexts/examples

    shared_context 'file record on database' do
      before do
        DownloadedFile.track_file(
          checksum: file.checksum,
          checksum_type: file.checksum_type,
          local_path: file.local_path,
          size: file.size
        )
      end
    end

    shared_examples 'invalid tracked file on database' do
      it 'untracks the file in the database' do
        expect { validate_local_file }
          .to change { DownloadedFile.where(local_path: file.local_path).count }
          .from(1).to(0)
      end
    end

    shared_examples 'valid untracked file on disk' do
      it 'start tracking the local file in the database' do
        expect { validate_local_file }
          .to change { DownloadedFile.where(local_path: file.local_path).count }
          .from(0).to(1)

        file_record = DownloadedFile.find_by(local_path: file.local_path)

        expect(file_record).to have_attributes(
          checksum: file.checksum,
          checksum_type: file.checksum_type,
          local_path: file.local_path,
          file_size: file.size
        )
      end
    end

    shared_examples 'valid tracked file on disk' do
      it 'updates the database without creating a new record' do
        file_record_id = DownloadedFile.find_by(local_path: file.local_path).id

        expect { validate_local_file }
          .not_to change { DownloadedFile.where(local_path: file.local_path).count }

        updated_file_record = DownloadedFile.find_by(local_path: file.local_path)

        expect(updated_file_record).to have_attributes(
          id: file_record_id,
          checksum: file.checksum,
          checksum_type: file.checksum_type,
          local_path: file.local_path,
          file_size: file.size
        )
      end
    end

    # File and database verification

    shared_examples 'file/database integrity verification' do
      subject(:validate_local_file) do
        dummy_class.new(deep_verify).send(:validate_local_file, file)
      end

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
          DownloadedFile.track_file(
            checksum: 'invalid_checksum',
            checksum_type: file.checksum_type,
            local_path: file.local_path,
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

  describe '#find_valid_files_by_checksum' do
    let(:valid_file) do
      fixture_path = file_fixture('dummy_product/product/apples-0.1-0.x86_64.rpm').to_s
      file = instance_double(
        '::RMT::FileReference',
        local_path: File.join(tmp_dir, 'dummy_product/product/apples-0.1-0.x86_64.rpm'),
        checksum: '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851',
        checksum_type: 'SHA256',
        size: 1934
      )

      {
        description: 'the file is valid on both database and disk',
        file: file,
        source_path: fixture_path
      }
    end

    let(:invalid_size_file) do
      fixture_path = file_fixture('dummy_product/product/oranges-0.1-0.x86_64.rpm').to_s
      file = instance_double(
        '::RMT::FileReference',
        local_path: File.join(tmp_dir, 'dummy_product/product/oranges-0.1-0.x86_64.rpm'),
        checksum: '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851',
        checksum_type: 'SHA256',
        size: 1934
      )

      {
        description: 'the file is valid on database with invalid size on disk',
        file: file,
        source_path: fixture_path
      }
    end

    let(:invalid_checksum_file) do
      fixture_path = file_fixture('dummy_product/product/oranges-0.1-0.x86_64.rpm').to_s
      file = instance_double(
        '::RMT::FileReference',
        local_path: File.join(tmp_dir, 'dummy_product/product/lemons-0.1-0.x86_64.rpm'),
        checksum: '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851',
        checksum_type: 'SHA256',
        size: 1933
      )

      {
        description: 'the file is valid on database with invalid checksum on disk',
        file: file,
        source_path: fixture_path
      }
    end

    let(:missing_file_on_disk) do
      file = instance_double(
        '::RMT::FileReference',
        local_path: File.join(tmp_dir, 'dummy_product/product/grapes-0.1-0.x86_64.rpm'),
        checksum: '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851',
        checksum_type: 'SHA256',
        size: 1934
      )

      {
        description: 'the file is valid on database but missing on disk',
        file: file,
        source_path: nil
      }
    end

    shared_context 'create valid tracked files' do
      before do
        valid_files.each { |f| create_and_track_file(f[:file], f[:source_path]) }
      end
    end

    shared_context 'create invalid tracked files' do
      before do
        invalid_records.each { |f| create_and_track_file(f[:file], f[:source_path]) }
      end
    end

    shared_examples 'invalid file records on database' do
      it 'removes invalid file records from the database' do
        invalid_record_paths = invalid_records.map { |f| f[:file].local_path }

        expect { find_valid_files_by_checksum }
          .to change { DownloadedFile.count }.by(-invalid_records.count)
          .and change {
            DownloadedFile.where(local_path: invalid_record_paths).count
          }.from(invalid_records.count).to(0)
      end
    end

    shared_examples 'invalid files on disk' do
      it 'removes invalid files from the disk' do
        previous_state = invalid_files.map { |f| [f[:file].local_path, true] }.to_h
        expected_state = invalid_files.map { |f| [f[:file].local_path, false] }.to_h

        expect { find_valid_files_by_checksum }
          .to change {
            invalid_files.map do |f|
              [f[:file].local_path, File.exist?(f[:file].local_path)]
            end.to_h
          }.from(previous_state).to(expected_state)
      end
    end

    shared_context 'create unique invalid file' do
      before do
        create_and_track_file(invalid_file[:file], invalid_file[:source_path])
      end

      let(:invalid_records) { [invalid_file] }
    end

    shared_examples 'invalid files on disk and on database' do
      include_examples 'invalid file records on database'
      include_examples 'invalid files on disk'
    end

    shared_examples 'valid files on both database and disk' do
      it 'returns a valid file path' do
        response = find_valid_files_by_checksum

        expect(response).to contain_records_like(valid_files.map { |f| f[:file] })
      end
    end

    shared_examples 'finding valid files by checksum' do
      subject(:find_valid_files_by_checksum) do
        dummy_class.new(deep_verify)
          .send(:find_valid_files_by_checksum, checksum, checksum_type)
      end

      context 'when no records on database match the given checksum' do
        it('returns nil') { is_expected.to be_empty }
      end

      context 'when two or more files on database match the checksum' do
        context 'and none of the files are valid on disk' do
          include_context 'create invalid tracked files'

          it('returns nil') { is_expected.to be_empty }

          include_examples 'invalid file records on database'
          include_examples 'invalid files on disk'
        end

        context 'and at least one of the files are valid on disk' do
          include_context 'create valid tracked files'
          include_context 'create invalid tracked files'

          include_examples 'valid files on both database and disk'
          include_examples 'invalid files on disk and on database'
        end
      end

      context 'when only one file on database matches the checksum but its size is invalid on disk' do
        let(:invalid_files) { [invalid_size_file] }
        let(:invalid_records) { [invalid_size_file] }

        include_context 'create invalid tracked files'

        include_examples 'invalid files on disk and on database'
      end

      context 'when only one file on database matches the checksum but is missing on disk' do
        let(:invalid_files) { [missing_file_on_disk] }
        let(:invalid_records) { [invalid_size_file] }

        include_context 'create invalid tracked files'

        include_examples 'invalid file records on database'
      end

      context 'when only one file on database matches the checksum and it is valid on disk' do
        let(:valid_files) { [valid_file] }

        include_context 'create valid tracked files'

        include_examples 'valid files on both database and disk'
      end
    end

    context 'with deep verification disabled' do
      let(:deep_verify) { false }

      let(:checksum) { '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851' }
      let(:checksum_type) { 'SHA256' }

      let(:valid_files) { [valid_file, invalid_checksum_file] }
      let(:invalid_files) { [invalid_size_file] }
      let(:invalid_records) { invalid_files + [missing_file_on_disk] }

      include_examples 'finding valid files by checksum'

      context 'when only one file on database matches the checksum but its checksum is invalid on disk' do
        let(:valid_files) { [invalid_checksum_file] }

        include_context 'create valid tracked files'

        include_examples 'valid files on both database and disk'
      end
    end

    context 'with deep verification enabled' do
      let(:deep_verify) { true }

      let(:checksum) { '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851' }
      let(:checksum_type) { 'SHA256' }

      let(:valid_files) { [valid_file] }
      let(:invalid_files) { [invalid_size_file, invalid_checksum_file] }
      let(:invalid_records) { invalid_files + [missing_file_on_disk] }

      include_examples 'finding valid files by checksum'

      context 'when only one file on database matches the checksum but its checksum is invalid on disk' do
        let(:invalid_files) { [invalid_checksum_file] }
        let(:invalid_records) { [invalid_checksum_file] }

        include_context 'create invalid tracked files'

        include_examples 'invalid files on disk and on database'
      end
    end
  end
end
