namespace :regsharing do
  desc 'Share registrations to the sibling servers'
  task sync: :environment do
    RegistrationSharing.sync_marked_systems
  end
end
