# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :hw_info do
    transient do
      virtual false
      instance_data nil
    end

    cpus 2
    sockets 1
    hypervisor nil
    arch 'x86_64'
    uuid { SecureRandom.uuid }

    after :build do |hw_info, evaluator|
      hw_info.hypervisor = 'KVM' if evaluator.virtual
      hw_info.instance_data = evaluator.instance_data
    end
  end
end
