class AddMigrationKindToProductPredecessorAssociation < ActiveRecord::Migration[5.1]
  def change
    add_column :product_predecessors, :kind, :integer, null: false, default: 0
  end
end
