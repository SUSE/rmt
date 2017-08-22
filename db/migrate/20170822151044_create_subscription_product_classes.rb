class CreateSubscriptionProductClasses < ActiveRecord::Migration[5.1]

  def change
    create_table :subscription_product_classes do |t|
      t.integer :subscription_id
      t.string :product_class
    end

    add_foreign_key :subscription_product_classes, :subscriptions, on_delete: :cascade
    add_index :subscription_product_classes, %i[subscription_id product_class], unique: true, name: 'index_product_class_unique'
  end

end
