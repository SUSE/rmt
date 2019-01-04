namespace :regsharing do
  desc 'Share registrations to peer servers'
  task sync: :environment do
    require 'registration_sharing/sync_job'
    RegistrationSharing::SyncJob.new.run
  end
end
