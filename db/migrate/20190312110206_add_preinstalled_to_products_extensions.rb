class AddPreinstalledToProductsExtensions < ActiveRecord::Migration[5.1]
  def change
    add_column :products_extensions, :preinstalled, :boolean, default: false
  end
end
