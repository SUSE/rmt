class ChangeSccIdColumn < ActiveRecord::Migration[5.1]

  def change
    remove_column :repositories, :scc_id, 'BIGINT UNSIGNED', after: :id
    add_column :repositories, :unique_id, :string, after: :id
    add_column :repositories, :custom, :boolean, default: false
  end

end
