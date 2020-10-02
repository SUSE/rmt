# :nocov:
locale = (ENV['LANG'] || ENV['LC_CTYPE']).to_s.match(/^([a-z]{2,}(_[A-Z]{2,})?)/).to_a[1] || :en
FastGettext.set_locale(locale.to_sym)
# :nocov:
