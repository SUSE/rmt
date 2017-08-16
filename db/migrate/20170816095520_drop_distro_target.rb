class DropDistroTarget < ActiveRecord::Migration[5.1]
  def change
    remove_column :repositories, :distro_target, :string
  end
end
