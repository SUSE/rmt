# rubocop:disable Style/NumericLiterals
unless Rails.env.production?
  StrongMigrations.start_after = 20200205123840
  StrongMigrations.lock_timeout_limit = 0
end
# rubocop:enable Style/NumericLiterals
