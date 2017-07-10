module ActionController
  class TranslatedError < RuntimeError

    attr_accessor :message, :localized_message, :status

    def initialize(error: 'Error occurred', localized_error: _(error), status: :unprocessable_entity)
      @message           = error
      @localized_message = localized_error
      @status            = status
    end

  end
end
