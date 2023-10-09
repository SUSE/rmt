class RemoveFriendlyNameFromProducts < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      remove_column :products, :friendly_name, :string
    end
  end
end
