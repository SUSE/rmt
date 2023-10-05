# rubocop:disable Style/NumericLiterals
unless Rails.env.production?
  StrongMigrations.start_after = 20200205123840
  StrongMigrations.lock_timeout_limit = 86400.seconds
end
# rubocop:enable Style/NumericLiterals
