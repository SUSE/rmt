class AddIsCustomToRepositories < ActiveRecord::Migration[5.1]

  def change
    add_column :repositories, :is_custom, :boolean, default: false
  end

end
