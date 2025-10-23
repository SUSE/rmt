namespace :db do
  namespace :maintenance do
    desc 'Delete orphaned system data profiles records'
    task cleanup_system_data_profiles: :environment do
      # TODO: Should this also factor in created_at/updated_at?
      # determine set of orphaned system data profiles entries
      orphans = SystemDataProfile.left_join(:system_profiles).where(system_profiles: { id: nil })

      count = orphans.count

      if count.zero?
        puts 'No orphan system data profile records detected.'
      else
        puts "Deleting #{count} orphaned system data profile records..."
        # TODO: Should this be a delete_all?
        orphans.destroy_all
        puts 'Orphans deleted successfully.'
      end
    end
  end
end
