class RemoveUniquenessFromDownloadedFilesChecksum < ActiveRecord::Migration[5.2]
  def change
    remove_index :downloaded_files, name: :index_downloaded_files_on_checksum_type_and_checksum, if_exists: true
    add_index :downloaded_files, %i[checksum_type checksum]
  end
end
