class ChangeDataType < ActiveRecord::Migration[6.1]
  def up
    # change the column to MEDIUMTEXT (limit of 16 MB)
    safety_assured do
      change_column :profiles, :data, :text, limit: 16.megabytes
    end
  end

  def down
    change_column :profiles, :data, :text
  end
end
