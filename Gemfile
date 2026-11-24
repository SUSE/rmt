source 'https://rubygems.org'
ruby '>= 3.4', '< 4.1'

# Rails components instead of the rails meta-gem. This leaves out actionmailer/actionmailbox
# (CVE-2026-42256, bsc#1265369) and unused actioncable, actiontext, activestorage.
rails_version = ['~> 8.1.4', '>= 8.1.4.1']
gem 'railties', *rails_version
gem 'activesupport', *rails_version
gem 'activemodel', *rails_version
gem 'activerecord', *rails_version
gem 'activejob', *rails_version
gem 'actionpack', *rails_version
gem 'actionview', *rails_version

# Server, database, jobs
gem 'bootsnap', require: false
gem 'puma'
gem 'mysql2'
gem 'strong_migrations'
gem 'sidekiq'

# API
gem 'versionist'
gem 'responders'
gem 'active_model_serializers'

# Metrics (Prometheus exporter)
gem 'yabeda'
gem 'yabeda-rails'
gem 'yabeda-puma-plugin'
gem 'yabeda-prometheus'

# Configuration and i18n
gem 'config'
gem 'fast_gettext'
gem 'gettext_i18n_rails'

# CLI (rmt-cli)
gem 'thor'
gem 'terminal-table'
gem 'csv'

# Repository mirroring
gem 'typhoeus'
gem 'nokogiri'
gem 'repomd_parser'
gem 'ruby-xz' # Debian Packages.xz
gem 'fiddle' # required by ruby-xz, no longer a default gem since Ruby 3.5

# Registry engine (container registry auth)
gem 'jwt'
gem 'base32'

group :development, :test do
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'sqlite3' # experimental sqlite backend, CI only

  # Keep these 3 in sync with glue
  gem 'scc-codestyle', '~> 0.7.0'
  gem 'rubocop', '<= 1.75.3'
  gem 'rubocop-ast', '<= 1.44.1'

  # gettext_i18n_rails rake tasks
  gem 'gettext', require: false
  gem 'ruby_parser', require: false
end

group :development do
  gem 'ronn-ng' # builds the rmt-cli man page (make man)
end

group :test do
  gem 'rspec-rails'
  gem 'rspec-its'
  gem 'shoulda-matchers'
  gem 'factory_bot_rails'
  gem 'ffaker'
  gem 'webmock'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'webrick' # test HTTP server in http_request_spec
  gem 'simplecov', require: false
end
