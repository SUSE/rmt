class ProductPredecessorAssociation < ApplicationRecord

  self.table_name = 'product_predecessors'

  validates :product_id, presence: true
  validates :predecessor_id, presence: true

end
