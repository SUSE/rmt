$LOAD_PATH.push File.expand_path(__dir__, '..')

require 'registration_sharing/engine'

module RegistrationSharing
  def self.share(_obj)
    return if Settings.try(:regsharing).try(:peers).blank?
  end
end
