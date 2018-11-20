# Used by cli apps (rmt-cli, rmt-data-import) to initialize i18n
require 'fast_gettext'

require_relative 'initializers/fast_gettext'

# rubocop:disable Style/MixinUsage
include FastGettext::Translation
# rubocop:enable Style/MixinUsage

locale = (ENV['LANG'] || ENV['LC_CTYPE']).to_s.match(/^([a-z]{2,}(_[A-Z]{2,})?)/).to_a[1] || :en
FastGettext.set_locale(locale.to_sym)
