namespace :db do
  namespace :maintenance do
    desc 'Delete all uptime tracking data  which are older than 90 days'
    task cleanup_uptime_tracking: :environment do
      SystemUptime.where("online_at_day < '#{2.days.ago}'").delete_all
    end
  end
end
