class DropObsoleteProducts < ActiveRecord::Migration[6.1]
  def up
    # SLES for SAP Applications got renamed to lowercase and got a new product ID (2985, 2986)
    Product.where(id: [2934, 2935], name: 'SUSE Linux Enterprise Server for SAP Applications').destroy_all
    # HA 16.0 aarch64 variant is not publically released
    Product.where(id: [2938], name: 'SUSE Linux Enterprise High Availability Extension').destroy_all
  end
end
