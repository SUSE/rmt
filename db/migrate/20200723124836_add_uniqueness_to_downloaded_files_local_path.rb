class AddUniquenessToDownloadedFilesLocalPath < ActiveRecord::Migration[5.2]
  def change
    logger = RMT::Logger.new(STDOUT)

    logger.info(_('Adding index to `downloaded_files.local_path` before querying duplicates...'))
    add_index :downloaded_files, :local_path, unique: false

    logger.info(_('Removing duplicated records on `downloaded_files.local_path`...'))
    ActiveRecord::Base.connection.execute(
      <<~SQL
        DELETE df1 FROM downloaded_files AS df1
            JOIN(
                SELECT local_path, max(id) AS max_id FROM downloaded_files
                GROUP BY downloaded_files.local_path
                HAVING (count(*) > 1)
            ) AS df2
            ON df1.local_path = df2.local_path
        WHERE df1.id != df2.max_id
      SQL
    )

    # Add unique index to `local_path`
    logger.info(_('Adding an unique index to `downloaded_file.local_path`...'))
    remove_index :downloaded_files, name: :index_downloaded_files_on_local_path, if_exists: true
    add_index :downloaded_files, :local_path, unique: true
  end
end
