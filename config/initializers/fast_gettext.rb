# Configure fast_gettext for i18n.
FastGettext.add_text_domain('glue', path: 'locale', type: :po, ignore_fuzzy: true, report_warning: false)
FastGettext.default_locale = I18n.default_locale
FastGettext.default_available_locales = %w[en de fr ja es pt_BR zh_CN]
FastGettext.default_text_domain = 'glue'
