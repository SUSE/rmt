ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

require_relative '../lib/rmt/config'
require 'rails/command'
require 'rails/commands/server/server_command'

Rails::Command::ServerCommand.send(:remove_const, 'DEFAULT_PORT')
Rails::Command::ServerCommand.const_set('DEFAULT_PORT', 4224)
