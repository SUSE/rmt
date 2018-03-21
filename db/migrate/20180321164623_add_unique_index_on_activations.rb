class AddUniqueIndexOnActivations < ActiveRecord::Migration[5.1]
  def change
    add_index :activations, %i[system_id service_id], unique: true
  end
end
