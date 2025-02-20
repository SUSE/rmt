class MakeSccIdUnique < ActiveRecord::Migration[6.0]
  def sqlite?
    ActiveRecord::Base.connection.adapter_name == 'SQLite'
  end

  def change
    logger = RMT::Logger.new(STDOUT)

    logger.info('Adding index to `repositories.scc_id` before querying duplicates...')
    add_index :repositories, :scc_id, unique: false

    # This only matters for existing databases. Since SQLite3 support has been
    # introduced at a much later stage, no databases should be affected by this.
    unless sqlite?
      logger.info('Removing duplicated records on `repositories.scc_id`...')
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
    end

    # Add unique index to `local_path`
    logger.info('Adding an unique index to `repositories.scc_id`...')
    remove_index :repositories, name: :index_repositories_on_scc_id, if_exists: true
    add_index :repositories, :scc_id, unique: true
  end
end
