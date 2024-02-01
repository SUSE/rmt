class RemoveObsoleteRes7Repositories < ActiveRecord::Migration[6.1]
  def change
    # RES7 was historically a product managed by Novell. With the upcoming
    # SUSE Liberty 7, RES7 was moved into IBS (SUSE build service).
    # This resulted in repositories being renamed.
    # This migration removes the now obsolete repositories, since RMT does
    # not remove these automatically.

    # Affected repositories are:
    # - 1963: https://updates.suse.com/repo/$RCE/RES7/src/
    # - 1736: https://updates.suse.com/repo/$RCE/RES7/x86_64/
    Repository.where(scc_id: [1963, 1736]).destroy_all
  end
end
