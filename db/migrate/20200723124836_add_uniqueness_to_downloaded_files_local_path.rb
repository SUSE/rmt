class AddUniquenessToDownloadedFilesLocalPath < ActiveRecord::Migration[5.2]
  def change
    # Remove duplicates before adding uniqueness to `local_path`
    ActiveRecord::Base.connection.execute(
      <<~SQL
        DELETE df1 FROM
            downloaded_files AS df1,
            downloaded_files AS df2
            WHERE df1.id < df2.id AND
                df1.local_path = df2.local_path
      SQL
    )

    add_index :downloaded_files, :local_path, unique: true
  end
end
