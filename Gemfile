protocol =  ENV['BROKEN_DOCKER_SSL'] ? 'http' : 'https'

source "#{protocol}://rubygems.org"

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

# Those are the gems with native extensions. The versions are locked to exact versions we have in our OBS:
# https://build.suse.de/project/show/Devel:SCC:SMT-NG

gem 'nio4r', '2.1.0'
gem 'nokogiri', '1.6.1'
gem 'mini_portile2', '2.1.0'
gem 'websocket-driver', '0.6.4'
gem 'puma', '3.6.0'
gem 'sqlite3', '1.3.10'

# The rest of Gemfile goes as normal

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
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails', '~> 3.5'
  gem 'rubocop', '~> 0.48.1', require: false
  gem 'rubocop-rspec'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'versionist'
gem 'responders'
