begin
  ::RMT::Db.setup!
rescue ::RMT::Db::TimeoutReachedError
  Rails.logger.error "Database connection timed out!"
  exit 1
end

# Create the `/usr/share/rmt/system_uuid` file if it does not exist already. This
# will ease up the first run of `rmt-cli` inside of this container.
unless File.exist?('/usr/share/rmt/system_uuid')
  system('dmidecode -s system-uuid > /usr/share/rmt/system_uuid')
end

# bundle if we have updates ready
system('bundle install')

# Run rails and therefore the API
system('bundle exec rails s -b rmt -p 4224')
