class RemoveLtss7FromProducts < ActiveRecord::Migration[6.1]
  def change
    products = Product.where(cpe: 'cpe:/o:suse:res-ha-ltss:7')

    products.each(&:destroy)
  end
end
