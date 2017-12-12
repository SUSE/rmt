class AddDownloadedFiles < ActiveRecord::Migration[5.1]

  def change
    create_table :downloaded_files do |t|
      t.string :checksum_type
      t.string :checksum
      t.string :local_path
    end

    add_index :downloaded_files, %i[checksum_type checksum], unique: true
  end

end
