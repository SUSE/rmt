class ResetSystemSync < ActiveRecord::Migration[6.1]
  def change
    System.update_all(scc_synced_at: nil)
  end
end
