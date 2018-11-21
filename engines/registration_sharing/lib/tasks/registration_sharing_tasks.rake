namespace :regsharing do
  desc 'Share registrations to the sibling servers'
  task sync: :environment do
    require 'registration_sharing/sync_job'
    RegistrationSharing::SyncJob.new.run
  end
end
