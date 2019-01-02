$LOAD_PATH.push File.expand_path(__dir__, '..')

require 'instance_verification/engine'

module InstanceVerification
  class << self
    attr_accessor :provider
  end
end

Dir.glob(File.join(__dir__, 'instance_verification/providers/*.rb')) do |f|
  require_relative f
  break
end
