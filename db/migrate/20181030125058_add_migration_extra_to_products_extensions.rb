class AddMigrationExtraToProductsExtensions < ActiveRecord::Migration[5.1]
  def change
    add_column :products_extensions, :migration_extra, :boolean, default: false
  end
end
