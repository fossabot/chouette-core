FactoryBot.define do
  factory :stop_area_provider do
    objectid {"MyString"}
    name {"MyString"}
    
    association :workbench, factory: :workbench
  end
end
