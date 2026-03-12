git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

source 'https://rubygems.org'
ruby '~> 3.4'

gem 'rails', '~> 8.1.0'

gem 'bootsnap', require: false

gem 'ostruct'
gem 'csv'

gem 'puma'
gem 'mysql2'
gem 'sqlite3'

gem 'nokogiri'
gem 'thor'

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
gem 'rackup'

# Prometheus Exporter:
gem 'yabeda'
gem 'yabeda-rails'
gem 'yabeda-puma-plugin'
gem 'yabeda-prometheus'

gem 'strong_migrations'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  # These 3 gems below will be updated after we discuss about the next lint configuration
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
  gem 'guard-rspec', require: false
end

group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'ffaker'
  gem 'mixlib-shellout'
  gem 'rspec-its'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'shoulda-matchers'
  gem 'webmock'
  gem 'fuubar'
  gem 'timecop'
  gem 'vcr'
  gem 'coveralls_reborn'
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

# Needed to parse Debian's Packages.xz
gem 'ruby-xz'
gem 'resque'

gem 'fiddle'

gem 'ronn-ng'

gem 'repomd_parser'
