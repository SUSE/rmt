class BackfillAddMigrationExtraToProductsExtensions < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    ProductsExtensionsAssociation.where.not(migration_extra: true).in_batches.update_all migration_extra: false
  end
end
