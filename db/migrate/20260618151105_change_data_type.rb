class ChangeDataType < ActiveRecord::Migration[8.1]
  def up
    # change the column to MEDIUMTEXT (limit of 16 MB)
    change_column :profiles, :data, :text, limit: 16.megabytes
  end

  def down
    change_column :profiles, :data, :text
  end
end
