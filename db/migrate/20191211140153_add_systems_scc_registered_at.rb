class AddSystemsSccRegisteredAt < ActiveRecord::Migration[5.1]
  def change
    add_column :systems, :scc_registered_at, :datetime
  end
end
