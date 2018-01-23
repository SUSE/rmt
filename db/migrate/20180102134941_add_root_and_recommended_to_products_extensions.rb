class AddRootAndRecommendedToProductsExtensions < ActiveRecord::Migration[5.1]

  def change
    add_column :products_extensions, :recommended, :boolean
    add_column :products_extensions, :root_product_id, :integer
    add_index :products_extensions, %i[product_id extension_id root_product_id],
              unique: true, name: 'index_products_extensions_on_product_extension_root'

    reversible do |dir|
      dir.up do
        ProductsExtensionsAssociation.find_each.each do |pa|
          base = pa.product
          pa.root_product = base.bases.present? ? base.bases.first : base
          pa.recommended = false
          pa.save!
        end
        change_column_null(:products_extensions, :root_product_id, false)
      end
    end
  end

end
