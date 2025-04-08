FactoryBot.define do
  factory :registry_access_scope, class: 'AccessScope' do
    type { 'repository' }
    namespace { 'suse' }
    image { 'sles:15.4' }
    actions { ['pull'] }

    initialize_with { new(type: type, name: "#{namespace}/#{image}", actions: actions) }
  end
end
