class SystemProfile < ApplicationRecord
  # relationships
  belongs_to :system
  belongs_to :profile

  # callbacks
  after_commit :destroy_orphaned_profile, on: :destroy

  def destroy_orphaned_profile
    # if another racing orphan deletion has already deleted this
    # profile entry then the in memory reference may now be nil,
    # so there is nothing remaining for us to do.
    return unless profile

    # lock the profiles table to ensure that racing orphan checks
    # can accurately determine if there are no remaining references
    # to the specific data profile entry.
    profile.with_lock do
      if profile.system_profiles.none?
        # no remaining references so we can safely delete it
        profile.destroy
      end
    end
  rescue ActiveRecord::RecordNotFound
    # another racing orphan cleanup has already deleted this
    # profile so we don't need to do anything
  end
end
