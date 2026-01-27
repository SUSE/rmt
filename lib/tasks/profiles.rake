namespace :db do
  namespace :maintenance do
    desc 'Delete orphaned profiles records'
    task cleanup_profiles: :environment do
      orphans = Profile.left_join(:system_profiles).where(system_profiles: { id: nil })

      if orphans.count.zero?
        puts 'No orphaned profile records detected.'
      else
        puts "Deleting #{orphans.count} orphaned profile records..."
        orphans.destroy_all
        puts 'Orphaned profile records deleted.'
      end
    end
  end
end
