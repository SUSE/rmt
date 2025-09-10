namespace :db do
  namespace :maintenance do
    desc 'Delete system data profiles not seen in more that 18 months'
    task cleanup_system_data_profiles: :environment do
      SystemDataProfile.where("last_seen_at < '#{18.months.ago}'").delete_all
    end
  end
end
