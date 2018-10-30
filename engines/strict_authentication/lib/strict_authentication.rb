#Dir["#{__dir__}/../{app,config,db,lib}/*"].each do |entry|
#  puts entry
#end

$:.push File.expand_path(__dir__, '..')

require "strict_authentication/engine"

module StrictAuthentication
end
