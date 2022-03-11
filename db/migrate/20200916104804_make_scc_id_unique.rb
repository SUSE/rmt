class MakeSccIdUnique < ActiveRecord::Migration[6.0]
  def change
    logger = RMT::Logger.new(STDOUT)

    logger.info(_('Adding index to `repositories.scc_id` before querying duplicates...'))
    add_index :repositories, :scc_id, unique: false

    logger.info(_('Removing duplicated records on `repositories.scc_id`...'))
    ActiveRecord::Base.connection.execute(
      <<~SQL
      UPDATE repositories as r1
        JOIN(
          SELECT scc_id FROM repositories
          GROUP BY repositories.scc_id
          HAVING (count(*) > 1)
        ) AS r2
        ON r1.scc_id = r2.scc_id
      SET r1.scc_id = NULL
      WHERE r1.scc_id = r2.scc_id;
      SQL
    )

    # Add unique index to `local_path`
    logger.info(_('Adding an unique index to `repositories.scc_id`...'))
    remove_index :repositories, name: :index_repositories_on_scc_id, if_exists: true
    add_index :repositories, :scc_id, unique: true
  end
end
