# frozen_string_literal: true

begin
  ::RMT::Db.setup!
rescue ::RMT::Db::TimeoutReachedError
  Rails.logger.error "Database connection timed out!"
  exit 1
end

# Create the `/var/lib/rmt/system_uuid` file if it does not exist already. This
# will ease up the first run of `rmt-cli` inside of this container.
unless File.exist?('/var/lib/rmt/system_uuid')
  system('dmidecode -s system-uuid > /var/lib/rmt/system_uuid')
end

system('bundle exec rails s -b rmt -p 4224')
