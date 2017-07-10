module ActionController
  class ParameterMissingTranslated < TranslatedError

    def initialize(*missing_params)
      super N_('Required parameters are missing or empty: %s'), missing_params.join(', ')
    end

  end
end

