class RemoveFriendlyNameFromProducts < ActiveRecord::Migration[5.1]
  def change
    remove_column :products, :friendly_name, :string
  end
end
