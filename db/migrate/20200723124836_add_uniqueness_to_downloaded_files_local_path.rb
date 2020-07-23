class AddUniquenessToDownloadedFilesLocalPath < ActiveRecord::Migration[5.2]
  def change
    # Remove duplicates before adding uniqueness to `local_path`
    unique_ids = DownloadedFile.group(:local_path).select('max(id)')
    DownloadedFile.where.not(id: unique_ids).delete_all

    add_index :downloaded_files, :local_path, unique: true
  end
end
