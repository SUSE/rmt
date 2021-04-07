$LOAD_PATH.push File.expand_path(__dir__, '..')

module InstanceVerification
  class << self
    # The public cloud instance verification is relying on
    # this variable being shared across threads (https://bugzilla.suse.com/show_bug.cgi?id=1183413)
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_accessor :provider
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes
  end

  class Exception < RuntimeError; end
end

module InstanceVerification::Providers
end

require 'instance_verification/engine'
require 'instance_verification/provider_base'

providers = Dir.glob(File.join(__dir__, 'instance_verification/providers/*.rb'))

raise 'Too many instance verification providers found' if providers.size > 1

providers.each do |f|
  require_relative f
  break
end
