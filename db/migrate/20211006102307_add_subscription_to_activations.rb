class AddSubscriptionToActivations < ActiveRecord::Migration[6.1]
  def change
    add_column :activations, :subscription_id, :bigint
    add_foreign_key :activations, :subscriptions
  end
end
