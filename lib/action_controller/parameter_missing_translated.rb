module ActionController
  class ParameterMissingTranslated < TranslatedError

    def initialize(*missing_params)
      super error:           N_('Required parameters are missing or empty: %s') % missing_params.join(', '),
            localized_error: _('Required parameters are missing or empty: %s') % missing_params.join(', ')
    end

  end
end

ActionDispatch::ExceptionWrapper.rescue_responses['ActionController::ParameterMissingTranslated'] = :unprocessable_entity
