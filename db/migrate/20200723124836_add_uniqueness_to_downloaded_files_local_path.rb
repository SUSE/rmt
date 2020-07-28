class AddUniquenessToDownloadedFilesLocalPath < ActiveRecord::Migration[5.2]
  def change
    # Remove duplicates before adding uniqueness to `local_path`
    ActiveRecord::Base.connection.execute(
      <<~SQL
        DELETE FROM `downloaded_files`
        WHERE `downloaded_files`.`id` NOT IN (
            SELECT * FROM (
                SELECT max(`files`.`id`) AS unique_id FROM `downloaded_files` AS `files`
                INNER JOIN `downloaded_files` ON `downloaded_files`.`id`=`files`.`id`
                GROUP BY `files`.`local_path`
            ) as tmp
        )
      SQL
    )

    add_index :downloaded_files, :local_path, unique: true
  end
end
