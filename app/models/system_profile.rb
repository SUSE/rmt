class SystemProfile < ApplicationRecord
  # relationships
  belongs_to :system
  belongs_to :profile

  # callbacks
  after_commit :destroy_orphaned_profile, on: :destroy

  # NOTE: Without locking, racing destroy handlers may detect each
  # others profile entry references via the system_profiles table
  # and thus decide to skip deleting the associated profile entry.
  # Using locking serializes the reference checking, potentially
  # mitigating any staleness issues that can arrise due to DB backend
  # optimisations, meaning that checks are performed against actual
  # table state, ensuring that at least one handler will see that all
  # other references have been removed and thus correctly decide to
  # delete the orphaned profile.
  # As such this approach should eliminate the need to schedule a
  # background job to detect and delete orphaned profile entries.
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
    logger.debug('orphaned profile already deleted by another racing destroy handler')
  end
end
