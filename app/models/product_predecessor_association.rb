class ProductPredecessorAssociation < ApplicationRecord
  self.table_name = 'product_predecessors'

  enum kind: { online: 0, offline: 1 }

  validates :product_id, :predecessor_id, :kind, presence: true
end
