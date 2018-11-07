ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

require_relative '../lib/rmt/config'
require 'rails/command'
require 'rails/commands/server/server_command'
require 'fast_gettext'

Rails::Command::ServerCommand.send(:remove_const, 'DEFAULT_PORT')
Rails::Command::ServerCommand.const_set('DEFAULT_PORT', 4224)

rmt_path = File.expand_path('../', __dir__)
FastGettext.add_text_domain('rmt', path: File.join(rmt_path, 'locale'), type: :po, ignore_fuzzy: true, report_warning: false)

FastGettext.text_domain = 'rmt'
FastGettext.available_locales = %w[en de fr ja es pt_BR zh_CN]
FastGettext.default_locale = :en

# rubocop:disable Style/MixinUsage
include FastGettext::Translation
# rubocop:enable Style/MixinUsage

locale = (ENV['LANG'] || ENV['LC_CTYPE']).to_s.match(/^([a-z]{2,}(_[A-Z]{2,})?)/).to_a[1] || :en
FastGettext.set_locale(locale.to_sym)
