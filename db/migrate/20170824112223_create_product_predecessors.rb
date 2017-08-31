class CreateProductPredecessors < ActiveRecord::Migration[5.1]

  def change
    create_table :product_predecessors do |t|
      t.references :product, foreign_key: { on_delete: :cascade }, null: false
      t.integer 'predecessor_id'
    end

    add_index 'product_predecessors', %i[product_id predecessor_id], name: 'index_product_predecessors_on_product_id_and_predecessor_id', unique: true
  end

end
