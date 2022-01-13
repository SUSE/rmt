# This migration gets rid off a bug introduced in SCC where some non-SUSE
# products with negative IDs were visible. This should never have happened since
# they are managed elsewhere. Purge them now if this is the case for this
# registration proxy.
class RemoveProductsNegativeId < ActiveRecord::Migration[6.1]
  def change
    Product.where('id < ?', 0).destroy_all
  end
end
