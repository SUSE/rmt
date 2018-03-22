class AddForeignKeyConstraints < ActiveRecord::Migration[5.1]
  def change
    add_foreign_key :activations, :services, on_delete: :cascade
    add_foreign_key :product_predecessors, :products, column: :predecessor_id
    add_foreign_key :products_extensions, :products, column: :root_product_id
    add_foreign_key :services, :products
  end
end
