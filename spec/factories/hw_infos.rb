# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :hw_info do
    transient do
      virtual false
    end

    cpus 2
    sockets 1
    hypervisor nil
    arch 'x86_64'

    after :build do |hw_info, evaluator|
      hw_info.hypervisor = 'KVM' if evaluator.virtual
    end
  end
end
