class CreateSubscriptionProductClasses < ActiveRecord::Migration[5.1]

  def change
    create_table :subscription_product_classes do |t|
      t.references :subscription, foreign_key: { on_delete: :cascade }, null: false
      t.string :product_class, null: false
    end

    add_index :subscription_product_classes, %i[subscription_id product_class], unique: true, name: 'index_product_class_unique'
  end

end
