class AddFileSizeToDownloadedFiles < ActiveRecord::Migration[5.1]

  def change
    add_column :downloaded_files, :file_size, 'BIGINT UNSIGNED'
  end

end
