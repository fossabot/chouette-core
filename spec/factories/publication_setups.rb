FactoryBot.define do
  factory :publication_setup do
    sequence(:name) { |n| "Publication #{n}" }
    workgroup { create(:workgroup) }
    enabled {false}
    export_type {"Export::Gtfs"}
    export_options { { duration: 200, prefer_referent_stop_area: false, ignore_single_stop_station: false } }
  end

  factory :publication_setup_gtfs, :parent => :publication_setup do
    export_type {"Export::Gtfs"}
    export_options { { duration: 200, prefer_referent_stop_area: false, ignore_single_stop_station: false } }
  end

  factory :publication_setup_netex_generic, :parent => :publication_setup do
    export_type {"Export::NetexGeneric"}
    export_options { { duration: 200, profile: :none } }
  end

  factory :publication_setup_idfm_netex_full, :parent => :publication_setup do
    export_type {"Export::Netex"}
    export_options { {export_type: :full, duration: 60} }
  end

end
