class AddIsCustomToRepositories < ActiveRecord::Migration[5.1]

  def change
    add_column :repositories, :custom, :boolean, default: false
  end

end
