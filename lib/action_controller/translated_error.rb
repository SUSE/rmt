module ActionController
  class TranslatedError < RuntimeError

    attr_accessor :message, :localized_message, :status

    def initialize(error = 'Error occurred', *params)
      @message           = error % params
      @localized_message = _(error) % params
      @status            = :unprocessable_entity
    end

  end
end
