class AddFriendlyVersionToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :friendly_version, :string
  end
end
