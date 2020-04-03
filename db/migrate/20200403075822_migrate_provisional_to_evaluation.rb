class MigrateProvisionalToEvaluation < ActiveRecord::Migration[5.1]
  def change
    Subscription.where(kind: 'provisional').update_all(kind: 'evaluation')
  end
end
