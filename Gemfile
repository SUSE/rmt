source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 7.0.0'

gem 'bootsnap', require: false

gem 'puma'
gem 'mysql2'
gem 'sqlite3'

gem 'nokogiri'
gem 'thor'
gem 'repomd_parser'

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

# Prometheus Exporter:
gem 'yabeda'
gem 'yabeda-rails'
gem 'yabeda-puma-plugin'
gem 'yabeda-prometheus'

gem 'strong_migrations'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'scc-codestyle', '~> 0.5.0'
  gem 'rubocop', '<= 1.25.0'
  gem 'rubocop-ast', '<= 1.17.0'
  gem 'gettext', require: false # needed for gettext_i18n_rails tasks
  gem 'ruby_parser', require: false # needed for gettext_i18n_rails tasks, Locked because of Ruby >= 2.6 dependency
  gem 'gettext_test_log'
  gem 'memory_profiler'
  gem 'awesome_print'
end

group :development do
  gem 'listen'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen'
  gem 'spring-commands-rspec'
  gem 'ronn-ng'
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
  gem 'coveralls', '~> 0.8.21', require: false # coveralls_reborn is the newer gem as this one was archived
  gem 'minitest'
  gem 'public_suffix'
  gem 'webrick'
end

gem 'simplecov', require: false, group: :test

gem 'versionist'
gem 'responders'
gem 'typhoeus'
gem 'active_model_serializers'

# i18n
gem 'fast_gettext'
gem 'gettext_i18n_rails'

gem 'config'
gem 'terminal-table'

# needed by rmt-server-pubcloud
gem 'jwt', '~> 2.1'
gem 'base32'
gem 'resque'
