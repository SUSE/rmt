class AddUniquenessToDownloadedFilesLocalPath < ActiveRecord::Migration[5.2]
  def change
    # Remove duplicates before adding uniqueness to `local_path`
    logger = RMT::Logger.new(STDOUT)

    logger.info(_('Finding `downloaded_files.local_path` duplicated records...'))
    duplicated_records = DownloadedFile.find_by_sql(
      <<~SQL
        SELECT df1.* FROM downloaded_files AS df1
            JOIN(
                SELECT local_path, max(id) AS max_id FROM downloaded_files
                GROUP BY downloaded_files.local_path
                HAVING (count(*) > 1)
            ) AS df2
            ON df1.local_path = df2.local_path
        WHERE df1.id != df2.max_id
      SQL
    )

    duplicated_count = duplicated_records.count
    if duplicated_count > 0
      logger.info(_("#{duplicated_count} duplicated records have been found"))
      duplicated_records.each do |file|
        logger.info(_("Removing record: ID #{file.id} with path '#{file.local_path}'"))
        file.destroy
      end
    else
      logger.info(_('No duplicated records has been found.'))
    end

    # Add index with uniqueness to `local_path`
    logger.info(_('Adding index to `downloaded_file.local_path` with an uniqueness constraint...'))
    logger.info(_('(This step can take some time to complete.)'))
    add_index :downloaded_files, :local_path, unique: true
  end
end
