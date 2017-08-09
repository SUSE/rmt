source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

# Those are the gems with native extensions. The versions are locked to exact versions we have in our OBS:
# https://build.suse.de/project/show/Devel:SCC:SMT-NG

gem 'nio4r', '2.1.0'
# gem 'nokogiri', '1.6.1'
# gem 'mini_portile2', '2.1.0'
gem 'websocket-driver', '0.6.4'
gem 'puma', '3.6.0'
gem 'pg', '0.18.3'

# The rest of Gemfile goes as normal

gem 'nokogiri', '~> 1.8.0'
gem 'rails', '~> 5.1'

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
  gem 'rspec-rails', '~> 3.5'
  gem 'scc-codestyle'
  gem 'factory_girl_rails'
  gem 'shoulda-matchers'
  gem 'ffaker'
  gem 'rspec-its'
  gem 'gettext', require: false # needed for gettext_i18n_rails tasks
  gem 'ruby_parser', require: false # needed for gettext_i18n_rails tasks
  gem 'gettext_test_log'
  gem 'memory_profiler'
  gem 'webmock'

  # Branch that contains fixes for recording and playing back Typhoeus requests with on_headers and on_body callbacks
  # Hopefully it will get merged some time soon :-)
  gem 'vcr', github: 'ikapelyukhin/vcr', branch: 'issue_509'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
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

gem 'config', '~> 1.0'
gem 'terminal-table', '~> 1.8'
