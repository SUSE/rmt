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



module FastGettextPatch
  require 'fast_gettext/vendor/poparser'
  refine FastGettext::GetText::PoParser do
    def detect_file_encoding(po_file)
      open(po_file, encoding: 'ASCII-8BIT') do |input|
        input.each_line do |line|
          return Encoding.find(Regexp.last_match(1)) if /"Content-Type:.*\scharset=(.*)\\n"/ =~ line
        end
      end
      Encoding.default_external
    end
  end
end

using FastGettextPatch
