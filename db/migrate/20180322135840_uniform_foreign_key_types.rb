class UniformForeignKeyTypes < ActiveRecord::Migration[5.1]
  def up
    change_column :activations, :service_id, :bigint
    change_column :product_predecessors, :predecessor_id, :bigint
    change_column :products_extensions, :root_product_id, :bigint
    change_column :services, :product_id, :bigint
  end

  def down
    change_column :activations, :service_id, :integer
    change_column :product_predecessors, :predecessor_id, :integer
    change_column :products_extensions, :root_product_id, :integer
    change_column :services, :product_id, :integer
  end
end
