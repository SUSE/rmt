source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'puma', '~> 5.6.2'
gem 'mysql2', '~> 0.5.3'

gem 'nokogiri', '< 1.13' # Locked because of Ruby >= 2.6 dependency
gem 'thor'
gem 'activesupport', '~> 6.1.6'
gem 'actionpack', '~> 6.1.6'
gem 'actionview', '~> 6.1.6'
gem 'activemodel', '~> 6.1.6'
gem 'activerecord', '~> 6.1.6'
gem 'railties', '~> 6.1.6'
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
  gem 'scc-codestyle', '<= 0.5.0' # Locked because of Ruby >= 2.6 dependency
  gem 'rubocop', '<= 1.25' # Locked because of Ruby >= 2.6 dependency
  gem 'rubocop-ast', '<= 1.17.0' # Locked because of Ruby >= 2.6 dependency
  gem 'gettext', require: false # needed for gettext_i18n_rails tasks
  gem 'ruby_parser', require: false # needed for gettext_i18n_rails tasks
  gem 'gettext_test_log'
  gem 'memory_profiler'
  gem 'strong_migrations'
  gem 'awesome_print'
end

group :development do
  gem 'listen', '>= 3.0.5', '<= 3.6.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'spring-commands-rspec'
  gem 'ronn'
  gem 'guard-rspec', require: false
end

group :test do
  gem 'rspec-command', '1.0.3'
  gem 'rspec-rails', '~> 5.0'
  gem 'factory_bot_rails', '~> 6.2.0'
  gem 'ffaker'
  gem 'rspec-its'
  gem 'fakefs', '~> 1.4', require: 'fakefs/safe'
  gem 'shoulda-matchers'
  gem 'webmock'
  gem 'fuubar'
  gem 'timecop'
  gem 'vcr', '~> 6.0'
  gem 'coveralls', '~> 0.8.21', require: false
  gem 'minitest', '~> 5.15.0' # minitest 5.16 needs Ruby >= 2.6
end

gem 'simplecov', require: false, group: :test

gem 'versionist'
gem 'responders'
gem 'typhoeus'
gem 'active_model_serializers'

# i18n
gem 'fast_gettext', '~> 2.2'
gem 'gettext_i18n_rails'

gem 'config', '~> 3.0', '>= 2.2.1'
gem 'terminal-table', '~> 3.0'

# needed by rmt-server-pubcloud
gem 'jwt', '~> 2.1'
