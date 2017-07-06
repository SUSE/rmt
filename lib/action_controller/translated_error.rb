module ActionController
  class TranslatedError < RuntimeError

    attr_accessor :message, :localized_message

    def initialize(error: 'Error occurred', localized_error: _(error))
      @message           = error
      @localized_message = localized_error
    end

  end
end
