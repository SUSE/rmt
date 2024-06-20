class RemoveLtss7FromProducts < ActiveRecord::Migration[6.1]
  def change
    Product.where(cpe: "cpe:/o:suse:res-ha-ltss:7").destroy!
  end
end
