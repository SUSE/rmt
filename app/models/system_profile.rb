class SystemProfile < ApplicationRecord
  # relationships
  belongs_to :system
  belongs_to :system_data_profile

  # callbacks
  after_commit :destroy_orphaned_data_profile, on: :destroy

  private

  def destroy_orphaned_data_profile
    # if another racing orphan deletion has already deleted this
    # system data profile entry then the in memory reference may
    # now be nil, so there is nothing remaining for us to do.
    return unless system_data_profile

    # lock the system_data_profiles table to ensure that racing
    # orphan checks can accurately determine if there are no
    # remaining references to the specific data profile entry.
    system_data_profile.with_lock do
      if system_data_profile.system_profiles.none?
        # no remaining references so we can safely delete it
        system_data_profile.destroy
      end
    end
  rescue ActiveRecord::RecordNotFound
    # another racing orphan cleanup has already deleted this
    # data profile so we don't need to do anything
  end
end
