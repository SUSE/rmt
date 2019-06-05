# Configure fast_gettext for i18n.
require 'fast_gettext'

# rubocop:disable Style/MixinUsage
include FastGettext::Translation
# rubocop:enable Style/MixinUsage

rmt_path = File.expand_path('../../', __dir__)
FastGettext.add_text_domain('rmt', path: File.join(rmt_path, 'locale'), type: :po, ignore_fuzzy: true, report_warning: false)
FastGettext.default_locale = :en
FastGettext.available_locales = FastGettext.default_available_locales = %w[en de fr ja es pt_BR zh_CN]
FastGettext.text_domain = FastGettext.default_text_domain = 'rmt'
locale = (ENV['LANG'] || ENV['LC_CTYPE']).to_s.match(/^([a-z]{2,}(_[A-Z]{2,})?)/).to_a[1] || :en
FastGettext.set_locale(locale.to_sym)
