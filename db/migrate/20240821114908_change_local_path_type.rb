class ChangeLocalPathType < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      change_column :repositories, :local_path, :string, limit: 512
      change_column :downloaded_files, :local_path, :string, limit: 512
    end
  end

  def down
    change_column :repositories, :local_path, :string
    change_column :downloaded_files, :local_path, :string
  end
end
