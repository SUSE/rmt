class CreateProductPredecessors < ActiveRecord::Migration[5.1]

  def change
    create_table :product_predecessors do |t|
      t.integer 'product_id'
      t.integer 'predecessor_id'
    end

    add_foreign_key :product_predecessors, :products, on_delete: :cascade
    add_index 'product_predecessors', %i[product_id predecessor_id], name: 'index_product_predecessors_on_product_id_and_predecessor_id', unique: true
  end

end
