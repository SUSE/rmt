class AddIndexToSystemsLastSeenAt < ActiveRecord::Migration[8.1]
  def up
    # 'rmt-cli systems purge' filters on last_seen_at, which was unindexed and
    # forced a full scan of Systems table on every batch
    #
    # Single column on purpose: InnoDB appends the primary key to every
    # secondary index, so [:last_seen_at, :id] would be identical on disk
    #
    # choosing :inplace on purpose
    # on a table this size a silent fallback to a full table
    # copy would lock it for hours
    # this makes the ALTER fail immediately instead
    add_index :systems, :last_seen_at, algorithm: :inplace
  end

  def down
    remove_index :systems, :last_seen_at
  end
end
