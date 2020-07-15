class RemoveUniquenessFromDownloadedFilesChecksum < ActiveRecord::Migration[5.2]
  def change
    remove_index :downloaded_files, name: :index_downloaded_files_on_checksum_type_and_checksum
    add_index :downloaded_files, [:checksum_type, :checksum]
  end
end
