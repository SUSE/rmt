source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'puma', '3.12.6'
gem 'mysql2', '~> 0.5.3'

gem 'nokogiri', '~> 1.10.3'
gem 'thor'
gem 'activesupport', '~> 5.2.4'
gem 'actionpack', '~> 5.2.4'
gem 'actionview', '~> 5.2.4'
gem 'activemodel', '~> 5.2.4'
gem 'activerecord', '~> 5.2.4'
gem 'railties', '~> 5.2.4'
gem 'repomd_parser', '~> 0.1.4'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'scc-codestyle'
  gem 'gettext', require: false # needed for gettext_i18n_rails tasks
  gem 'ruby_parser', require: false # needed for gettext_i18n_rails tasks
  gem 'gettext_test_log'
  gem 'memory_profiler'
  gem 'danger'
  gem 'danger-rubocop'
  gem 'strong_migrations'
end

group :development do
  gem 'awesome_print'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'spring-commands-rspec'
  gem 'ronn'
  gem 'guard-rspec', require: false
end

group :test do
  gem 'rspec-command', '1.0.3'
  gem 'rspec-rails', '~> 3.5'
  gem 'factory_girl_rails', '4.8.0'
  gem 'ffaker'
  gem 'rspec-its'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'shoulda-matchers'
  gem 'webmock'
  gem 'fuubar'
  gem 'timecop'
  gem 'vcr', '~> 4.0'
  gem 'coveralls', '~> 0.8.21', require: false
end

gem 'simplecov', require: false, group: :test

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'versionist'
gem 'responders'
gem 'typhoeus', '~> 1.1', '>= 1.1.2'
gem 'active_model_serializers'

# i18n
gem 'fast_gettext'
gem 'gettext_i18n_rails'

gem 'config', '~> 2.2', '>= 2.2.1'
gem 'terminal-table', '~> 1.8'

# needed by rmt-server-pubcloud
gem 'jwt', '~> 2.1'
