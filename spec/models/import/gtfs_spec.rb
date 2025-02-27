RSpec.describe Import::Gtfs do

  let(:workbench) do
    create :workbench do |workbench|
      workbench.line_referential.update objectid_format: "netex"
      workbench.stop_area_referential.update objectid_format: "netex"
    end
  end

  def create_import(file)
    i = build_import(file)
    i.save!
    i
  end

  def build_import(file)
    Import::Gtfs.new workbench: workbench, local_file: open_fixture(file), creator: "test", name: "test"
  end

  context "when the file is not directly accessible" do
    let(:import) {
      Import::Gtfs.create workbench: workbench, name: "test", creator: "Albator", file: open_fixture('google-sample-feed.zip')
    }

    before(:each) do
      allow(import).to receive(:file).and_return(nil)
    end

    it "should still be able to update the import" do
      import.update status: :failed
      expect(import.reload.status).to eq "failed"
    end
  end

  describe '#force_failure!' do
    let(:import) { create_import 'google-sample-feed.zip' }

     it 'should fail the parent import and the referential' do
        parent = create(:workbench_import)
        resoure = create(:import_resource, import: parent, referential: create(:referential))
        import.update parent: parent
        parent.reload

        import.prepare_referential

        expect(parent).to receive(:force_failure!).and_call_original
        expect(parent).to receive(:do_force_failure!).and_call_original

        import.force_failure!
        expect(import.referential.reload.state).to eq :failed
        expect(import.reload.status).to eq 'failed'
        expect(parent.reload.status).to eq 'failed'
        expect(resoure.reload.referential.state).to eq :failed
     end
  end

  describe "created referential" do
    let(:import) { build_import 'google-sample-feed.zip' }

    it "is named with the import name" do
      import.name = "Import Name"
      import.prepare_referential
      expect(import.referential.name).to eq(import.name)
    end
  end

  describe "#import_agencies" do
    let(:import) { create_import 'google-sample-feed-agency-phone.zip' }
    it "should create a company for each agency" do
      import.import_agencies
      expect(workbench.line_referential.companies.pluck(:registration_number, :name, :default_contact_url, :default_contact_phone, :default_language, :time_zone)).to eq([["DTA","Demo Transit Authority","http://google.com","+33 1 23 45 67 89","en","America/Los_Angeles"]])
    end

    it "should create a resource" do
      expect { import.import_agencies }.to change { import.resources.count }.by 1
      resource = import.resources.last
      expect(resource.name).to eq 'agencies'
      expect(resource.metrics['ok_count'].to_i).to eq 1
      expect(resource.metrics['warning_count'].to_i).to eq 0
      expect(resource.metrics['error_count'].to_i).to eq 0
    end

    context 'when a record lacks its name' do
      before(:each) do
        allow(import.source).to receive(:agencies) {
          [
            GTFS::Agency.new(
              id: 'DTA',
              name: '',
              url: 'http://google.com',
              timezone: 'America/Los_Angeles'
            ),
            GTFS::Agency.new(
              id: 'DTA 2',
              name: 'name',
              url: 'http://google.com',
              timezone: 'America/Los_Angeles'
            )
          ]
        }
      end
      it 'should create a message and continue' do
        companies_count = Chouette::Company.count
        expect do
          import.import_agencies
        end.to change { Import::Message.count }.by 1
        expect(Chouette::Company.count).to eq companies_count + 1
        resource = import.resources.last
        expect(resource.name).to eq 'agencies'
        expect(resource.metrics['ok_count'].to_i).to eq 1
        expect(resource.metrics['warning_count'].to_i).to eq 0
        expect(resource.metrics['error_count'].to_i).to eq 1
      end
    end

    context 'when a record does not have an id' do
      before(:each) do
        allow(import.source).to receive(:agencies) {
          [
            GTFS::Agency.new(
              id: 'DTA',
              name: 'name',
              url: 'http://google.com',
              timezone: 'America/Los_Angeles'
            ),
            GTFS::Agency.new(
              id: '',
              name: 'name',
              url: 'http://google.com',
              timezone: 'America/Los_Angeles'
            )
          ]
        }
      end

      it 'should not create a company' do
        expect do
          import.import_agencies
        end.to change { Chouette::Company.count }.by 1
      end

      it 'should create an error message' do
        expect do
          import.import_agencies
        end.to change { Import::Message.count }.by 1

        resource = import.resources.last
        expect(resource.metrics['ok_count'].to_i).to eq 1
        expect(resource.metrics['warning_count'].to_i).to eq 0
        expect(resource.metrics['error_count'].to_i).to eq 1
      end

      it 'should create a default timezone' do
        expect(import).to receive(:check_time_zone_or_create_message).twice

        import.import_agencies
      end
    end
  end

  describe '#import_stops' do
    let(:import) { build_import 'google-sample-feed-with-stop-desc.zip' }
    it "should create a stop_area for each stop" do
      import.import_stops

      defined_attributes = [
        :registration_number, :name, :parent_id, :latitude, :longitude, :comment, :public_code, :mobility_restricted_suitability
      ]
      expected_attributes = [
        ["AMV", "Amargosa Valley (Demo)", nil, 36.641496, -116.40094,'amv', nil,false],
        ["EMSI", "E Main St / S Irving St (Demo)", nil, 36.905697, -116.76218,'emsi', nil,false],
        ["DADAN", "Doing Ave / D Ave N (Demo)", nil, 36.909489, -116.768242,'dadan', nil,false],
        ["NANAA", "North Ave / N A Ave (Demo)", nil, 36.914944, -116.761472,'nanaa', nil,false],
        ["NADAV", "North Ave / D Ave N (Demo)", nil, 36.914893, -116.76821,'nadav', nil,false],
        ["STAGECOACH", "Stagecoach Hotel & Casino (Demo)", nil, 36.915682, -116.751677,'stagecoach', nil,false],
        ["BULLFROG", "Bullfrog (Demo)", nil, 36.88108, -116.81797,'bullfrog', nil, true],
        ["BEATTY_AIRPORT", "Nye County Airport (Demo)", nil, 36.868446, -116.784582,'beatty_airport', 'Test',false],
        ["FUR_CREEK_RES", "Furnace Creek Resort (Demo)", nil, 36.425288, -117.133162,'fur_creek_res', '1',false]
      ]

      expect(workbench.stop_area_referential.stop_areas.pluck(*defined_attributes)).to match_array(expected_attributes)
    end

    it "should use the agency timezone by default" do
      import.import_agencies
      import.import_stops

      expect(workbench.stop_area_referential.stop_areas.first.time_zone).to eq("America/Los_Angeles")
    end

    context 'with an invalid timezone' do
      let(:stop) do
        GTFS::Stop.new(
          id: 'stop_id',
          name: 'stop',
          location_type: '2',
          timezone: "incorrect timezone"
        )
      end

      before(:each) do
        allow(import.source).to receive(:stops) { [stop] }
      end

      it 'should create an error message' do
        expect { import.import_stops }.to change { Import::Message.count }.by(1)
          .and(change { Chouette::StopArea.count })
      end
    end

    context 'with an inexistant parent stop' do
      let(:child) do
        GTFS::Stop.new(
          id: 'child_id',
          name: 'child',
          parent_station: 'parent_id',
          location_type: '2'
        )
      end

      before(:each) do
        allow(import.source).to receive(:stops) { [child] }
      end

      it 'should create an error message if the parent is inexistant' do
        expect { import.import_stops }.to change { Import::Message.count }.by(1)
          .and(change { Chouette::StopArea.count })
      end
    end

    context 'with parent defined after child' do
      let(:child_gtfs_stop) do
        GTFS::Stop.new(
          id: 'child_id',
          name: 'child',
          parent_station: 'parent_id',
          location_type: '2'
        )
      end

      let(:parent_gtfs_stop) do
        GTFS::Stop.new(
          id: 'parent_id',
          name: 'Parent',
          parent_station: '',
          location_type: '1'
        )
      end

      before(:each) do
        allow(import.source).to receive(:stops) { [child_gtfs_stop, parent_gtfs_stop] }
      end

      let(:child_stop_area) do
        Chouette::StopArea.find_by!(registration_number: child_gtfs_stop.id)
      end

      let(:parent_stop_area) do
        Chouette::StopArea.find_by!(registration_number: parent_gtfs_stop.id)
      end

      it 'should create an error message if the parent is inexistant' do
        expect { import.import_stops }.to change { Import::Message.count }.by(0)
                                            .and(change { Chouette::StopArea.count }.by(2))
        expect(child_stop_area.parent).to eq(parent_stop_area)
      end
    end

    context 'with a parent stop' do
      let(:parent) do
        GTFS::Stop.new(
          id: 'parent_id',
          name: 'parent',
          location_type: '1',
          timezone: 'America/Los_Angeles'
        )
      end

      let(:child) do
        GTFS::Stop.new(
          id: 'child_id',
          name: 'child',
          parent_station: 'parent_id',
          location_type: '2',
          timezone: 'Europe/Paris'
        )
      end

      before(:each) do
        allow(import.source).to receive(:stops) { [parent, child] }
      end

      it 'should link the stop_areas' do
        import.import_stops
        parent = Chouette::StopArea.find_by(registration_number: 'parent_id')
        child = Chouette::StopArea.find_by(registration_number: 'child_id')
        expect(child.parent).to eq parent
      end

      it 'should use the parent timezone' do
        import.import_stops
        child = Chouette::StopArea.find_by(registration_number: 'child_id')
        expect(child.time_zone).to eq 'America/Los_Angeles'
      end

      context 'when the parent is not valid' do
        let(:parent) do
          GTFS::Stop.new(
            id: 'parent_id',
            name: '',
            location_type: '1'
          )
        end

        it "should create the child and raise an error message" do
          expect { import.import_stops }.to change { Import::Message.count }.by(2)
            .and(change { Chouette::StopArea.count })
        end
      end
    end
  end

  describe '#import_transfers' do
    let(:import) { build_import 'google-sample-feed.zip' }
    it 'should create a ConnectionLink for each type 2 transfer' do
      import.prepare_referential
      expect { import.import_transfers }.to change { Chouette::ConnectionLink.count }.by 1
      link = Chouette::ConnectionLink.last
      expect(link.departure.registration_number).to eq 'BEATTY_AIRPORT'
      expect(link.arrival.registration_number).to eq 'FUR_CREEK_RES'
      expect(link.both_ways).to be_truthy
      expect(link.default_duration).to eq 6000
    end

    context 'with an existing connection' do
      before do
        import.prepare_referential
        from = import.referential.stop_area_referential.stop_areas.find_by registration_number: 'BEATTY_AIRPORT'
        to = import.referential.stop_area_referential.stop_areas.find_by registration_number: 'FUR_CREEK_RES'
        import.stop_area_provider.connection_links.create!(departure: from, arrival: to, both_ways: true, default_duration: 12)
      end

      it 'should not create a duplicate ConnectionLink' do
        import.prepare_referential
        expect { import.import_transfers }.to_not change { Chouette::ConnectionLink.count }
      end
    end

    context 'whith from_stop_id same as to_stop_id' do
      let(:import) { build_import 'google-sample-feed-with-incorrect-transfer.zip' }

      it 'should create a warning if a tranfer have the same from stop and to stop' do
        import.prepare_referential
        expect { import.import_transfers }.to change { Import::Message.count }.by(1)
      end
    end
  end


  describe '#import_routes' do
    let(:import) { build_import 'google-sample-feed-with-color.zip' }
    it 'should create a line for each route' do
      import.import_routes

      defined_attributes = [
        :registration_number, :name, :number, :published_name,
        "companies.registration_number", :comment, :url,
        :transport_mode, :color, :text_color
      ]
      expected_attributes = [
        ["AAMV", "Airport - Amargosa Valley", "50", "Airport - Amargosa Valley", nil, nil, nil, "bus", nil, nil],
        ["CITY", "City", "40", "City", nil, nil, nil, "bus", nil, nil],
        ["STBA", "Stagecoach - Airport Shuttle", "30", "Stagecoach - Airport Shuttle", nil, nil, nil, "bus",nil,nil],
        ["BFC", "Bullfrog - Furnace Creek Resort", "20", "Bullfrog - Furnace Creek Resort", nil, nil, nil, "bus","000000","ABCDEF"],
        ["AB", "Airport - Bullfrog", "10", "Airport - Bullfrog", nil, nil, nil, "bus","ABCDEF","012345"]
      ]

      expect(workbench.line_referential.lines.includes(:company).pluck(*defined_attributes)).to match_array(expected_attributes)
    end

    context "with a company" do
      let(:agency_name){ 'name' }
      let(:agency){
        GTFS::Agency.new(
          id: 'agency_id',
          name: agency_name,
          url: 'http://google.com',
          timezone: 'America/Los_Angeles'
        )
      }
      let(:route){
        GTFS::Route.new(
          id: 'route_id',
          short_name: 'route',
          agency_id: 'agency_id'
        )
      }
      before(:each) do
        allow(import.source).to receive(:agencies) { [agency] }
        allow(import.source).to receive(:routes) { [route] }
        import.import_agencies
      end

      it 'should link the line' do
        import.import_routes
        parent = Chouette::Company.find_by(registration_number: agency.id)
        child = Chouette::Line.find_by(registration_number: route.id)
        expect(child.company).to eq parent
      end

      context "when the agency is not valid" do
        let(:agency_name){ nil }

        it "shoud not create the line" do
          expect { import.import_routes }.to_not(change { Chouette::Line.count })
        end
      end
    end
  end

  describe "time_of_day" do
    context "with a UTC+1 Agency"do
      let(:import) { build_import 'time_of_day_feed_1.zip' }

      it "should have correct time of day values" do
        import.prepare_referential
        import.import_calendars
        import.import_stop_times

        expected_attributes = [
          ['S1','23:00:00 day:-1'],
          ['S2','23:00:05 day:-1']
        ]

        a = []
        referential.vehicle_journey_at_stops.each do |vjas|
          a << [
            vjas.stop_point.registration_number,
            vjas.departure_time_of_day.to_s
          ]
        end
        expect(a).to match_array(expected_attributes)
      end
    end

    context "with a UTC-8 Agency"do
      let(:import) { build_import 'time_of_day_feed_8.zip' }

      it "should have correct time of day values" do
        import.prepare_referential
        import.import_calendars
        import.import_stop_times

        expected_attributes = [
          ['S1','00:00:00 day:1'],
          ['S2','00:00:05 day:1']
        ]

        a = []
        referential.vehicle_journey_at_stops.each do |vjas|
          a << [
            vjas.stop_point.registration_number,
            vjas.departure_time_of_day.to_s
          ]
        end
        expect(a).to match_array(expected_attributes)
      end
    end
  end

  describe "#import_stop_times" do
    let(:import) { build_import 'google-sample-feed.zip' }

    before do
      import.prepare_referential
      import.import_calendars
      allow_any_instance_of(Chouette::Route).to receive(:has_tomtom_features?){ true }
    end

    it "should calculate costs" do
      calculated = []
      allow_any_instance_of(Chouette::Route).to receive(:calculate_costs!) { |route|
        calculated << route
      }

      import.import_stop_times
      import.referential.vehicle_journeys.map(&:route).uniq.each do |route|
        expect(calculated).to include(route)
      end
    end

    it "should create a Route for each trip" do
      import.import_stop_times
      defined_attributes = [
        "lines.registration_number", :wayback, :name, :published_name
      ]
      expected_attributes = [
        ["AB", "outbound", "to Bullfrog", "to Bullfrog"],
        ["AB", "inbound", "to Airport", "to Airport"],
        ["CITY", "inbound", "Inbound", "Inbound"],
        ["BFC", "outbound", "to Furnace Creek Resort", "to Furnace Creek Resort"],
        ["BFC", "inbound", "to Bullfrog", "to Bullfrog"],
        ["AAMV", "outbound", "to Amargosa Valley", "to Amargosa Valley"],
        ["AAMV", "inbound", "to Airport", "to Airport"],
      ]
      expect(import.referential.routes.includes(:line).pluck(*defined_attributes)).to match_array(expected_attributes)
    end

    it "should create a JourneyPattern for each trip" do
      import.import_stop_times
      defined_attributes = [
        :name
      ]
      expected_attributes = [
        "to Bullfrog",
        "to Airport",
        "Inbound",
        "to Furnace Creek Resort",
        "to Bullfrog",
        "to Amargosa Valley",
        "to Airport",
      ]
      expect(import.referential.journey_patterns.pluck(*defined_attributes)).to match_array(expected_attributes)
    end

    it "should create a VehicleJourney for each trip" do
      import.import_stop_times
      defined_attributes = ->(v) {
        [v.published_journey_name, v.time_tables.first&.comment]
      }
      expected_attributes = [
        ["CITY2", "FULLW"],
        ["AB1", "FULLW"],
        ["AB2", "FULLW"],
        ["BFC1", "FULLW"],
        ["BFC2", "FULLW"],
        ["AAMV1", "WE"],
        ["AAMV2", "WE"],
        ["AAMV3", "WE"],
        ["AAMV4", "WE"]
      ]
      expect(import.referential.vehicle_journeys.map(&defined_attributes)).to match_array(expected_attributes)
    end

    it "should create a VehicleJourneyAtStop for each stop_time" do
      import.import_stop_times

      def t(value)
        Time.parse(value)
      end

      expected_attributes = [
        ['EMSI', 0, t('2000-01-01 14:30:00 UTC'), t('2000-01-01 14:30:00 UTC'), 0, 0],
        ['DADAN', 1, t('2000-01-01 14:37:00 UTC'), t('2000-01-01 14:35:00 UTC'), 0, 0],
        ['NADAV', 2, t('2000-01-01 14:44:00 UTC'), t('2000-01-01 14:42:00 UTC'), 0, 0],
        ['NANAA', 3, t('2000-01-01 14:51:00 UTC'), t('2000-01-01 14:49:00 UTC'), 0, 0],
        ['STAGECOACH', 4, t('2000-01-01 14:58:00 UTC'), t('2000-01-01 14:56:00 UTC'), 0, 0],
        ['BEATTY_AIRPORT', 0, t('2000-01-01 23:00:00 UTC'), t('2000-01-01 23:00:00 UTC'), 0, 0],
        ['BULLFROG', 1, t('2000-01-01 00:05:00 UTC'), t('2000-01-01 00:00:00 UTC'), 1, 1],
        ['BULLFROG', 0, t('2000-01-01 20:05:00 UTC'), t('2000-01-01 20:05:00 UTC'), 0, 0],
        ['BEATTY_AIRPORT', 1, t('2000-01-01 20:15:00 UTC'), t('2000-01-01 20:15:00 UTC'), 0, 0],
        ['BULLFROG', 0, t('2000-01-01 16:20:00 UTC'), t('2000-01-01 16:20:00 UTC'), 0, 0],
        ['FUR_CREEK_RES', 1, t('2000-01-01 17:20:00 UTC'), t('2000-01-01 17:20:00 UTC'), 0, 0],
        ['FUR_CREEK_RES', 0, t('2000-01-01 19:00:00 UTC'), t('2000-01-01 19:00:00 UTC'), 0, 0],
        ['BULLFROG', 1, t('2000-01-01 20:00:00 UTC'), t('2000-01-01 20:00:00 UTC'), 0, 0],
        ['BEATTY_AIRPORT', 0, t('2000-01-01 16:00:00 UTC'), t('2000-01-01 16:00:00 UTC'), 0, 0],
        ['AMV', 1, t('2000-01-01 17:00:00 UTC'), t('2000-01-01 17:00:00 UTC'), 0, 0],
        ['BEATTY_AIRPORT', 0, t('2000-01-01 21:00:00 UTC'), t('2000-01-01 21:00:00 UTC'), 0, 0],
        ['AMV', 1, t('2000-01-01 22:00:00 UTC'), t('2000-01-01 22:00:00 UTC'), 1, 1],
        ['AMV', 0, t('2000-01-01 07:30:00 UTC'), t('2000-01-01 07:30:00 UTC'), 1, 1],
        ['BEATTY_AIRPORT', 1, t('2000-01-01 09:00:00 UTC'), t('2000-01-01 09:00:00 UTC'), 1, 1],
        ['AMV', 0, t('2000-01-01 18:00:00 UTC'), t('2000-01-01 18:00:00 UTC'), 0, 0],
        ['BEATTY_AIRPORT', 1, t('2000-01-01 19:00:00 UTC'), t('2000-01-01 19:00:00 UTC'), 0, 0]
      ]

      a = []
      referential.vehicle_journey_at_stops.each do |vjas|
        a << [
          vjas.stop_point.registration_number,
          vjas.stop_point.position,
          vjas.departure_time_of_day.to_vehicle_journey_at_stop_time,
          vjas.arrival_time_of_day.to_vehicle_journey_at_stop_time,
          vjas.departure_time_of_day.day_offset,
          vjas.arrival_time_of_day.day_offset
        ]
      end
      expect(a).to match_array(expected_attributes)
    end

    context 'with multiple trips with non zero first day offet' do
      let(:import) { build_import 'day-offset-sample-feed.zip' }

      it 'should reuse the calendars' do
        import.import_stop_times

        expect(referential.time_tables.count).to eq 2
      end
    end

    context 'with invalid stop times' do
      let(:import) { build_import 'invalid_stop_times.zip' }
      it "should create no VehicleJourney" do
        expect{ import.import_stop_times }.to_not change { Chouette::VehicleJourney.count }
      end
    end
  end

  describe '#import_calendars' do
    let(:import) { build_import 'google-sample-feed.zip' }

    before do
      import.prepare_referential
    end

    it "should create a Timetable for each calendar" do
      import.import_calendars

      def d(value)
        Date.parse(value)
      end

      defined_attributes = ->(t) {
        [t.comment, t.valid_days, t.periods.first.period_start, t.periods.first.period_end]
      }
      expected_attributes = [
        ['FULLW', [1, 2, 3, 4, 5, 6, 7], d('Mon, 01 Jan 2007'), d('Fri, 31 Dec 2010')],
        ['WE', [6, 7], d('Mon, 01 Jan 2007'), d('Fri, 31 Dec 2010')]
      ]
      expect(referential.time_tables.map(&defined_attributes)).to match_array(expected_attributes)
    end
  end

  describe '#import_calendars with short calendar' do
    let(:import) { build_import 'google-sample-feed-short-calendar.zip' }

    before do
      import.prepare_referential
    end

    it "should create a Date when a calendar starts and ends the same day" do
      import.import_calendars

      def d(value)
        Date.parse(value)
      end

      defined_attributes = ->(t) {
        [t.comment, t.valid_days, t.dates.first.date]
      }
      expected_attributes = [
        ['FULLW', [1, 2, 3, 4, 5, 6, 7], d('Mon, 01 Jan 2007')]
      ]
      expect(referential.time_tables.map(&defined_attributes)).to match_array(expected_attributes)
    end
  end

  describe '#import_calendar_dates' do
    let(:import) { build_import 'google-sample-feed.zip' }

    before do
      import.prepare_referential
    end

    it 'should create time_tables when they don\'t already exist' do
      expect{import.import_calendar_dates}.to change{Chouette::TimeTable.count}.by 1
      timetable = Chouette::TimeTable.last
      expect(timetable.comment).to eq 'FULLW'
      expect(timetable.periods.count).to eq 0
      expect(timetable.dates.count).to eq 1
      expect(timetable.dates.last.date).to eq '2007-06-04'.to_date
      expect(timetable.dates.last.in_out).to be_falsy

      timetable.dates.destroy_all
      expect { import.import_calendar_dates }.to change { Chouette::TimeTable.count }.by 0
    end

    context 'when the timetables exist' do
      before do
        import.import_calendars
      end

      it 'should create a Timetable::Date for each calendar date' do
        import.import_calendar_dates

        def d(value)
          Date.parse(value)
        end

        defined_attributes = lambda do |d|
          [d.time_table.comment, d.date, d.in_out]
        end
        expected_attributes = [
          ['FULLW', d('Mon, 04 Jun 2007'), false]
        ]
        expect(referential.time_table_dates.map(&defined_attributes)).to match_array(expected_attributes)
      end
    end

    context 'when one timetable is in error' do
      before(:each) do
        allow(import.source).to receive(:calendars) {
          [
            GTFS::Calendar.new(
              service_id: 'FULLW-ERR',
              monday: '1',
              tuesday: '1',
              wednesday: '1',
              thursday: '1',
              friday: '1',
              saturday: '1',
              sunday: '1',
              start_date: '20110101',
              end_date: '20101231'
            ),
            GTFS::Calendar.new(
              service_id: 'FULLW',
              monday: '1',
              tuesday: '1',
              wednesday: '1',
              thursday: '1',
              friday: '1',
              saturday: '1',
              sunday: '1',
              start_date: '20070101',
              end_date: '20101231'
            )
          ]
        }

        allow(import.source).to receive(:calendar_dates) {
          [
            GTFS::CalendarDate.new(
              service_id: 'FULLW',
              date: '20070604',
              exception_type: '2'
            ),
            GTFS::CalendarDate.new(
              service_id: 'FULLW-ERR',
              date: '20070604',
              exception_type: '2'
            )
          ]
        }
      end

      it 'should not create a Timetables' do
        import.import_calendars

        expect do
          import.import_calendar_dates
        end.to_not(change { Chouette::TimeTable.count })
      end

      it 'should set the importer as failed' do
        import.import
        expect(import.status).to eq 'failed'
      end

      it 'should create an error message' do
        import.import_calendars

        expect do
          import.import_calendar_dates
        end.to(change { Import::Message.count }.by(1))
      end
    end
  end

  describe "#import" do
    context "when there is an issue with the source file" do
      let(:import) { build_import 'google-sample-feed.zip' }
      it "should fail" do
        allow(import.source).to receive(:agencies){ raise GTFS::InvalidSourceException }
        expect { import.import }.to_not raise_error
        expect(import.status).to eq :failed
      end
    end
  end

  describe "#referential_metadata" do
    context 'without calendar_dates.xml' do
      let(:import) { build_import 'google-sample-feed-no-calendar_dates.zip' }
      it "should not raise an error" do
        expect { import.referential_metadata }.to_not raise_error
      end
    end
  end

  describe '#download_local_file' do
    let(:file) { 'google-sample-feed.zip' }
    let(:import) do
      Import::Gtfs.create! name: 'GTFS test', creator: 'Test', workbench: workbench, file: open_fixture(file), download_host: 'rails_host'
    end

    let(:download_url) { "#{import.download_host}/workbenches/#{import.workbench_id}/imports/#{import.id}/internal_download?token=#{import.token_download}" }

    before do
      stub_request(:get, download_url).to_return(status: 200, body: read_fixture(file))
    end

    it 'should download local_file' do
      expect(File.read(import.download_local_file)).to eq(read_fixture(file))
    end
  end

  describe '#download_uri' do
    let(:import) { Import::Gtfs.new }

    before do
      allow(import).to receive(:download_path).and_return('/download_path')
    end

    context "when download_host is 'front'" do
      before { allow(import).to receive(:download_host).and_return('front') }
      it 'returns http://front/download_path' do
        expect(import.download_uri.to_s).to eq('http://front/download_path')
      end
    end

    context "when download_host is 'front:3000'" do
      before { allow(import).to receive(:download_host).and_return('front:3000') }
      it 'returns http://front:3000/download_path' do
        expect(import.download_uri.to_s).to eq('http://front:3000/download_path')
      end
    end

    context "when download_host is 'http://front:3000'" do
      before { allow(import).to receive(:download_host).and_return('http://front:3000') }
      it 'returns http://front:3000/download_path' do
        expect(import.download_uri.to_s).to eq('http://front:3000/download_path')
      end
    end

    context "when download_host is 'https://front:3000'" do
      before { allow(import).to receive(:download_host).and_return('https://front:3000') }
      it 'returns https://front:3000/download_path' do
        expect(import.download_uri.to_s).to eq('https://front:3000/download_path')
      end
    end

    context "when download_host is 'http://front'" do
      before { allow(import).to receive(:download_host).and_return('http://front') }
      it 'returns http://front/download_path' do
        expect(import.download_uri.to_s).to eq('http://front/download_path')
      end
    end
  end

  describe '#download_host' do
    it 'should return host defined by Rails.application.config.rails_host' do
      allow(Rails.application.config).to receive(:rails_host).and_return('download_host')
      expect(Import::Gtfs.new.download_host).to eq('download_host')
    end
  end

  describe '#download_path' do
    let(:file) { 'google-sample-feed.zip' }
    let(:import) do
      Import::Gtfs.create! name: 'GTFS test', creator: 'Test', workbench: workbench, file: open_fixture(file), download_host: 'rails_host'
    end

    it 'should return the pathwith the token' do
      expect(import.download_path).to eq("/workbenches/#{import.workbench_id}/imports/#{import.id}/internal_download?token=#{import.token_download}")
    end
  end

  describe "#referential_metadata" do
    let(:import) { create_import "google-sample-feed.zip" }
    let(:start_date_limit) { Date.current.beginning_of_year - Import::Base::PERIOD_EXTREME_VALUE }
    let(:end_date_limit) { Date.current.end_of_year + Import::Base::PERIOD_EXTREME_VALUE }

    context "when dates are over the extremes" do
      before do
        allow(import.source).to receive(:calendars).and_return([
          double(start_date: (Date.current - 20.years).to_s, end_date: (Date.current + 20.years).to_s)
        ])
      end

      it "sets periodes within the allowed limit" do
        expect(import.referential_metadata.periodes).to eq([start_date_limit..end_date_limit])
      end
    end

    context "when dates are inside the extremes" do
      before do
        allow(import.source).to receive(:calendars).and_return([
          double(start_date: 1.month.ago.to_date.to_s, end_date: 1.year.since.to_date.to_s)
        ])
      end

      it "sets periodes within the allowed limit" do
        expect(import.referential_metadata.periodes).to eq([1.month.ago.to_date..1.year.since.to_date])
      end
    end
  end
end
