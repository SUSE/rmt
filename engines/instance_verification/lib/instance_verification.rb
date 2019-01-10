$LOAD_PATH.push File.expand_path(__dir__, '..')

require 'instance_verification/engine'

module InstanceVerification
  class << self
    attr_accessor :provider
  end
end

module InstanceVerification::Providers
end

providers = Dir.glob(File.join(__dir__, 'instance_verification/providers/*.rb'))

raise 'Too many instance verification providers found' if providers.size > 1

providers.each do |f|
  require_relative f
  break
end
