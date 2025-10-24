# :nocov:
locale = (ENV['LANG'] || ENV.fetch('LC_CTYPE', nil)).to_s.match(/^([a-z]{2,}(_[A-Z]{2,})?)/).to_a[1] || :en
FastGettext.set_locale(locale.to_sym)
# :nocov:
