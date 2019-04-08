require 'initializers/rmt_fast_gettext'

# enable comments in .po/.pot files prefixed with i18n tag (see rxgettext -h)
Rails.application.config.gettext_i18n_rails.xgettext = %w[--add-comments=i18n]
