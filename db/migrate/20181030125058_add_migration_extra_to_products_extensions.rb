class AddMigrationExtraToProductsExtensions < ActiveRecord::Migration[5.1]
  def up
    add_column :products_extensions, :migration_extra, :boolean unless column_exists?(:products_extensions, :migration_extra)
    change_column_default :products_extensions, :migration_extra, false
  end

  def down
    remove_column :products_extensions, :migration_extra
  end
end
