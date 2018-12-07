module RegistrationSharing
  class ApplicationController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods
  end
end
