class Import::Gtfs < Import::Base
  include LocalImportSupport

  after_commit :update_main_resource_status, on:  [:create, :update]

  def operation_progress_weight(operation_name)
    operation_name.to_sym == :stop_times ? 90 : 10.0/10
  end

  def operations_progress_total_weight
    100
  end

  def self.accepts_file?(file)
    Zip::File.open(file) do |zip_file|
      zip_file.glob('agency.txt').size == 1
    end
  rescue => e
    Chouette::Safe.capture "Error in testing GTFS file: #{file}", e
    return false
  end

  def referential_metadata
    registration_numbers = source.routes.map(&:id)
    line_ids = line_referential.lines.where(registration_number: registration_numbers).pluck(:id)

    start_dates = []
    end_dates = []

    if source.entries.include?('calendar.txt')
      start_dates, end_dates = source.calendars.map { |c| [c.start_date, c.end_date] }.transpose
    end

    included_dates = []
    if source.entries.include?('calendar_dates.txt')
      included_dates = source.calendar_dates.select { |d| d.exception_type == "1" }.map(&:date)
    end

    min_date = Date.parse (start_dates + [included_dates.min]).compact.min
    min_date = [min_date, Date.current.beginning_of_year - PERIOD_EXTREME_VALUE].max

    max_date = Date.parse (end_dates + [included_dates.max]).compact.max
    max_date = [max_date, Date.current.end_of_year + PERIOD_EXTREME_VALUE].min

    ReferentialMetadata.new line_ids: line_ids, periodes: [min_date..max_date]
  end

  def source
    @source ||= ::GTFS::Source.build local_file.path, strict: false
  end

  def prepare_referential
    import_resources :agencies, :stops, :routes, :shapes

    create_referential
    notify_operation_progress(:create_referential)
    referential.switch
  end

  def import_without_status
    prepare_referential

    if check_calendar_files_missing_and_create_message
      notify_operation_progress :calendars
      notify_operation_progress :calendar_dates
      notify_operation_progress :calendar_checksums
    else
      import_resources :calendars, :calendar_dates
    end

    import_resources :transfers if source.entries.include?('transfers.txt')

    import_resources :stop_times, :missing_checksums
  end

  def import_agencies
    create_resource(:agencies).each(source.agencies) do |agency, resource|
      company = line_referential.companies.find_or_initialize_by(registration_number: agency.id)
      company.attributes = { name: agency.name }
      company.default_language = agency.lang
      company.default_contact_url = agency.url
      @default_time_zone ||= check_time_zone_or_create_message(agency.timezone, resource)
      company.time_zone = @default_time_zone

      save_model company, resource: resource
    end
  end

  def default_time_zone
    @default_time_zone_instance ||= ActiveSupport::TimeZone[@default_time_zone]
  end

  def import_stops
    sorted_stops = source.stops.sort_by { |s| s.parent_station.present? ? 1 : 0 }
    @stop_areas_id_by_registration_number = {}
    CustomFieldsSupport.within_workgroup(workbench.workgroup) do
      create_resource(:stops).each(sorted_stops, slice: 100, transaction: true) do |stop, resource|
        stop_area = stop_area_referential.stop_areas.find_or_initialize_by(registration_number: stop.id)

        stop_area.name = stop.name
        stop_area.area_type = stop.location_type == '1' ? :zdlp : :zdep
        stop_area.latitude = stop.lat.presence && stop.lat.to_f
        stop_area.longitude = stop.lon.presence && stop.lon.to_f
        stop_area.kind = :commercial
        stop_area.deleted_at = nil
        stop_area.confirmed_at ||= Time.now
        stop_area.comment = stop.desc

        if stop.parent_station.present?
          if check_parent_is_valid_or_create_message(Chouette::StopArea, stop.parent_station, resource)
            parent = find_stop_parent_or_create_message(stop.name, stop.parent_station, resource)
            stop_area.parent = parent
            stop_area.time_zone = parent.try(:time_zone)
          end
        elsif stop.timezone.present?
          stop_area.time_zone = check_time_zone_or_create_message(stop.timezone, resource)
        else
          stop_area.time_zone = @default_time_zone
        end

        save_model stop_area, resource: resource
        @stop_areas_id_by_registration_number[stop_area.registration_number] = stop_area.id
      end
    end
  end

  def lines_by_registration_number(registration_number)
    @lines_by_registration_number ||= {}
    @lines_by_registration_number[registration_number] ||= line_referential.lines.includes(:company).find_or_initialize_by(registration_number: registration_number)
  end

  def import_routes
    CustomFieldsSupport.within_workgroup(workbench.workgroup) do
      create_resource(:routes).each(source.routes, transaction: true) do |route, resource|
        if route.agency_id.present?
          next unless check_parent_is_valid_or_create_message(Chouette::Company, route.agency_id, resource)
        end
        line = lines_by_registration_number(route.id)
        line.name = route.long_name.presence || route.short_name
        line.number = route.short_name
        line.published_name = route.long_name
        unless route.agency_id == line.company&.registration_number
          line.company = line_referential.companies.find_by(registration_number: route.agency_id) if route.agency_id.present?
        end
        line.comment = route.desc

        line.transport_mode = case route.type
        when '0', '5'
          'tram'
        when '1'
          'metro'
        when '2'
          'rail'
        when '3'
          'bus'
        when '7'
          'funicular'
        end

        line.transport_submode = 'undefined'

        # White is the default color in the gtfs spec
        line.color = parse_color route.color
        # Black is the default text color in the gtfs spec
        line.text_color = parse_color route.text_color, default: '000000'

        line.url = route.url

        save_model line, resource: resource
      end
    end
  end

  def vehicle_journey_by_trip_id
    @vehicle_journey_by_trip_id ||= {}
  end

  def import_transfers
    @trips = {}
    create_resource(:transfers).each(source.transfers, slice: 100, transaction: true) do |transfer, resource|
      next unless transfer.type == '2'
      from_id = @stop_areas_id_by_registration_number[transfer.from_stop_id]
      unless from_id
        create_message(
          {
            criticity: :error,
            message_key: 'gtfs.transfers.missing_stop_id',
            message_attributes: { stop_id: transfer.from_stop_id },
            resource_attributes: {
              filename: "#{resource.name}.txt",
              line_number: resource.rows_count,
              column_number: 0
            }
          },
          resource: resource,
          commit: true
        )
        next
      end
      to_id = @stop_areas_id_by_registration_number[transfer.to_stop_id]
      unless to_id
        create_message(
          {
            criticity: :error,
            message_key: 'gtfs.transfers.missing_stop_id',
            message_attributes: { stop_id: transfer.to_stop_id },
            resource_attributes: {
              filename: "#{resource.name}.txt",
              line_number: resource.rows_count,
              column_number: 0
            }
          },
          resource: resource,
          commit: true
        )
        next
      end

      connection = referential.stop_area_referential.connection_links.find_by(departure_id: from_id, arrival_id: to_id, both_ways: true)
      connection ||= referential.stop_area_referential.connection_links.find_or_initialize_by(departure_id: to_id, arrival_id: from_id, both_ways: true)
      if transfer.min_transfer_time.present?
        connection.default_duration = transfer.min_transfer_time
        if [:frequent_traveller_duration, :occasional_traveller_duration,
          :mobility_restricted_traveller_duration].any? { |k| connection.send(k).present? }
          create_message(
            {
              criticity: :warning,
              message_key: 'gtfs.transfers.replacing_duration',
              message_attributes: { from_id: transfer.from_stop_id, to_id: transfer.to_stop_id },
              resource_attributes: {
                filename: "#{resource.name}.txt",
                line_number: resource.rows_count,
                column_number: 0
              }
            },
            resource: resource,
            commit: true
          )
        end
      end
      save_model connection, resource: resource
    end
  end

  def process_trip(resource, trip, stop_times)
    begin
      raise InvalidTripSingleStopTime unless stop_times.many?

      journey_pattern = find_or_create_journey_pattern(resource, trip, stop_times)

      vehicle_journey = journey_pattern.vehicle_journeys.build route: journey_pattern.route, skip_custom_fields_initialization: true
      vehicle_journey.published_journey_name = trip.short_name.presence || trip.id

      time_table = referential.time_tables.find_by(id: time_tables_by_service_id[trip.service_id]) if time_tables_by_service_id[trip.service_id]
      if time_table
        vehicle_journey.time_tables << time_table
      else
        create_message(
          {
            criticity: :warning,
            message_key: 'gtfs.trips.unknown_service_id',
            message_attributes: { service_id: trip.service_id },
            resource_attributes: {
              filename: "#{resource.name}.txt",
              line_number: resource.rows_count,
              column_number: 0
            }
          },
          resource: resource,
          commit: true
        )
      end

      vehicle_journey.codes.build code_space: code_space, value: trip.id

      ApplicationModel.skipping_objectid_uniqueness do
          save_model vehicle_journey, resource: resource
      end

      stop_times.sort_by! { |s| s.stop_sequence.to_i }

      Chouette::VehicleJourneyAtStop.bulk_insert do |worker|
        journey_pattern.stop_points.each_with_index do |stop_point, i|
          add_stop_point stop_times[i], stop_point, journey_pattern, vehicle_journey, resource, worker
        end
      end

      journey_pattern.vehicle_journey_at_stops.reload
      save_model journey_pattern, resource: resource

    rescue Import::Gtfs::InvalidTripNonZeroFirstOffsetError, Import::Gtfs::InvalidTripTimesError, Import::Gtfs::InvalidTripSingleStopTime, Import::Gtfs::InvalidStopAreaError => e
      message_key = case e
        when Import::Gtfs::InvalidTripNonZeroFirstOffsetError
          'trip_starting_with_non_zero_day_offset'
        when Import::Gtfs::InvalidTripTimesError
          'trip_with_inconsistent_stop_times'
        when Import::Gtfs::InvalidTripSingleStopTime
          'trip_with_single_stop_time'
        when Import::Gtfs::InvalidStopAreaError
          'no_specified_stop'
        end
      create_message(
        {
          criticity: :error,
          message_key: message_key,
          message_attributes: {
            trip_id: trip.id
          },
          resource_attributes: {
            filename: "#{resource.name}.txt",
            line_number: resource.rows_count,
            column_number: 0
          }
        },
        resource: resource, commit: true
      )
      @status = 'failed'
    rescue Import::Gtfs::InvalidTimeError => e
      create_message(
        {
          criticity: :error,
          message_key: 'invalid_stop_time',
          message_attributes: {
            time: e.time,
            trip_id: vehicle_journey.published_journey_name
          },
          resource_attributes: {
            filename: "#{resource.name}.txt",
            line_number: resource.rows_count,
            column_number: 0
          }
        },
        resource: resource, commit: true
      )
      @status = 'failed'
    end
  end

  def journey_pattern_ids
    @journey_pattern_ids ||= {}
  end

  def trip_signature(trip, stop_times)
    [
      trip.route_id,
      trip.direction_id,
      trip.headsign.presence || trip.short_name,
    ] + stop_times.map(&:stop_id)
  end

  def find_or_create_journey_pattern(resource, trip, stop_times)
    journey_pattern_id = journey_pattern_ids[trip_signature(trip, stop_times)]
    return Chouette::JourneyPattern.find(journey_pattern_id) if journey_pattern_id
    stop_points = []

    line = line_referential.lines.find_by registration_number: trip.route_id
    route = referential.routes.build line: line
    route.wayback = (trip.direction_id == '0' ? :outbound : :inbound)
    name = route.published_name = trip.headsign.presence || trip.short_name.presence || route.wayback.to_s.capitalize
    route.name = name

    journey_pattern = route.journey_patterns.build name: name, published_name: name, skip_custom_fields_initialization: true

    stop_times.sort_by! { |s| s.stop_sequence.to_i }

    raise InvalidTripTimesError unless consistent_stop_times(stop_times)

    stop_points_with_times = stop_times.each_with_index.map do |stop_time, i|
      [stop_time, import_stop_time(stop_time, journey_pattern.route, resource, i)]
    end

    ApplicationModel.skipping_objectid_uniqueness do
        save_model route, resource: resource
    end

    stop_points = stop_points_with_times.map do |s|
      if stop_point = s.last
        @objectid_formatter ||= Chouette::ObjectidFormatter.for_objectid_provider(StopAreaReferential, id: referential.stop_area_referential_id)
        stop_point[:route_id] = journey_pattern.route.id
        stop_point[:objectid] = @objectid_formatter.objectid(stop_point)
        stop_point
      end
    end

    worker = nil
    if stop_points.compact.present?
      Chouette::StopPoint.bulk_insert(:route_id, :objectid, :stop_area_id, :position, return_primary_keys: true) do |w|
        stop_points.compact.each { |s| w.add(s.attributes) }
        worker = w
      end
      stop_points = Chouette::StopPoint.find worker.result_sets.last.rows
    else
      stop_points = []
    end

    Chouette::JourneyPatternsStopPoint.bulk_insert do |w|
      stop_points.each do |stop_point|
        w.add journey_pattern_id: journey_pattern.id, stop_point_id: stop_point.id
      end
    end

    journey_pattern.stop_points.reload
    journey_pattern.shortcuts_update_for_add(stop_points.last) if stop_points.present?

    ApplicationModel.skipping_objectid_uniqueness do
        save_model journey_pattern, resource: resource
    end

    journey_pattern_ids[trip_signature(trip, stop_times)] = journey_pattern.id
    journey_pattern
  end

  def import_stop_times
    CustomFieldsSupport.within_workgroup(workbench.workgroup) do
      resource = create_resource(:stop_times)
      Chouette::ChecksumManager.no_updates do
        source.to_enum(:each_trip_with_stop_times).each_slice(100) do |slice|
          Chouette::VehicleJourney.cache do
            Chouette::VehicleJourney.transaction do
              slice.each do |trip, stop_times|
                process_trip(resource, trip, stop_times)
              end
            end
          end
        end
      end
    end
  end

  def consistent_stop_times(stop_times)
    times = stop_times.map{|s| [s.arrival_time, s.departure_time]}.flatten.compact
    times.inject(nil) do |prev, current|
      current = current.split(':').map &:to_i

      if prev
        return false if prev.first > current.first
        return false if prev.first == current.first && prev[1] > current[1]
        return false if prev.first == current.first && prev[1] == current[1] && prev[2] > current[2]
      end

      current
    end
    true
  end

  def import_stop_time(stop_time, route, resource, position)
    unless_parent_model_in_error(Chouette::StopArea, stop_time.stop_id, resource) do

      if position == 0
        departure_time = GTFSTime.parse(stop_time.departure_time)
        raise InvalidTimeError.new(stop_time.departure_time) unless departure_time.present?
        arrival_time = GTFSTime.parse(stop_time.arrival_time)
        raise InvalidTimeError.new(stop_time.arrival_time) unless arrival_time.present?
        raise InvalidTripNonZeroFirstOffsetError unless departure_time.day_offset.zero? && arrival_time.day_offset.zero?
      end

      stop_area_id = @stop_areas_id_by_registration_number[stop_time.stop_id]
      raise InvalidStopAreaError unless stop_area_id.present?

      Chouette::StopPoint.new(stop_area_id: stop_area_id, position: position )
    end
  end

  def add_stop_point(stop_time, stop_point, journey_pattern, vehicle_journey, resource, worker)
    # JourneyPattern#vjas_add creates automaticaly VehicleJourneyAtStop
    vehicle_journey_at_stop = journey_pattern.vehicle_journey_at_stops.build(stop_point_id: stop_point.id)

    departure_time = GTFS::Time.parse(stop_time.departure_time)
    raise InvalidTimeError.new(stop_time.departure_time) unless departure_time.present?

    arrival_time = GTFS::Time.parse(stop_time.arrival_time)
    raise InvalidTimeError.new(stop_time.arrival_time) unless arrival_time.present?

    departure_time_of_day = TimeOfDay.create(departure_time, time_zone: default_time_zone).without_utc_offset
    arrival_time_of_day = TimeOfDay.create(arrival_time, time_zone: default_time_zone).without_utc_offset

    vehicle_journey_at_stop.vehicle_journey = vehicle_journey
    vehicle_journey_at_stop.departure_time_of_day = departure_time_of_day
    vehicle_journey_at_stop.arrival_time_of_day = arrival_time_of_day

    worker.add vehicle_journey_at_stop.attributes
  end

  def time_tables_by_service_id
    @time_tables_by_service_id ||= {}
  end

  def import_calendars
    return unless source.entries.include?('calendar.txt')

    Chouette::TimeTable.skipping_objectid_uniqueness do
      Chouette::ChecksumManager.no_updates do
        create_resource(:calendars).each(source.calendars, slice: 500, transaction: true) do |calendar, resource|
          time_table = referential.time_tables.build comment: calendar.service_id
          Chouette::TimeTable.all_days.each do |day|
            time_table.send("#{day}=", calendar.send(day))
          end
          if calendar.start_date == calendar.end_date
            time_table.dates.build date: calendar.start_date, in_out: true
          else
            time_table.periods.build period_start: calendar.start_date, period_end: calendar.end_date
          end
          time_table.shortcuts_update
          time_table.skip_save_shortcuts = true
          save_model time_table, resource: resource

          time_tables_by_service_id[calendar.service_id] = time_table.id
        end
      end
    end
  end

  def import_calendar_dates
    return unless source.entries.include?('calendar_dates.txt')

    positions = Hash.new{ |h, k| h[k] = 0 }
    Chouette::ChecksumManager.no_updates do
      Chouette::TimeTableDate.bulk_insert do |worker|
        create_resource(:calendar_dates).each(source.calendar_dates, slice: 500, transaction: true) do |calendar_date, resource|
          comment = "#{calendar_date.service_id}"
          unless_parent_model_in_error(Chouette::TimeTable, comment, resource) do
            time_table_id = time_tables_by_service_id[calendar_date.service_id]
            time_table_id ||= begin
              tt = referential.time_tables.build comment: comment
              save_model tt, resource: resource
              time_tables_by_service_id[calendar_date.service_id] = tt.id
            end

            worker.add position: positions[time_table_id], date: Date.parse(calendar_date.date), in_out: calendar_date.exception_type == "1", time_table_id: time_table_id
            positions[time_table_id] += 1
          end
        end
      end
    end
  end

  def import_missing_checksums
    Chouette::ChecksumUpdater.new(referential).update
  end

  def find_stop_parent_or_create_message(stop_area_name, parent_station, resource)
    parent = stop_area_referential.stop_areas.find_by(registration_number: parent_station)
    unless parent
      create_message(
        {
          criticity: :error,
          message_key: :parent_not_found,
          message_attributes: {
            parent_name: parent_station,
            stop_area_name: stop_area_name,
          },
          resource_attributes: {
            filename: "#{resource.name}.txt",
            line_number: resource.rows_count,
            column_number: 0
          }
        },
        resource: resource, commit: true
      )
    end
    return parent
  end

  def check_time_zone_or_create_message(imported_time_zone, resource)
    return unless imported_time_zone
    time_zone = TZInfo::Timezone.all_country_zone_identifiers.select{|t| t==imported_time_zone}[0]
    unless time_zone
      create_message(
        {
          criticity: :error,
          message_key: :invalid_time_zone,
          message_attributes: {
            time_zone: imported_time_zone,
          },
          resource_attributes: {
            filename: "#{resource.name}.txt",
            line_number: resource.rows_count,
            column_number: 0
          }
        },
        resource: resource, commit: true
      )
    end
    return time_zone
  end

  def check_calendar_files_missing_and_create_message
    if source.entries.include?('calendar.txt') || source.entries.include?('calendar_dates.txt')
      return false
    end

    create_message(
      {
        criticity: :error,
        message_key: 'missing_calendar_or_calendar_dates_in_zip_file',
      },
      resource: resource, commit: true
    )
    @status = 'failed'
  end

  def parse_color value, options = {}
    options = {default: 'FFFFFF'}.merge(options)
    /\A[\dA-F]{6}\Z/.match(value).try(:string) || options[:default]
  end

  class InvalidTripNonZeroFirstOffsetError < StandardError; end
  class InvalidTripTimesError < StandardError; end
  class InvalidTripSingleStopTime < StandardError; end
  class InvalidStopAreaError < StandardError; end
  class InvalidTimeError < StandardError
    attr_reader :time

    def initialize(time)
      @time = time
    end
  end

  def import_shapes
    Shapes.new(self).import!
  end

  class Shapes

    def initialize(import)
      @import = import
    end

    attr_reader :import
    delegate :source, :workbench, to: :import
    delegate :workgroup, to: :workbench

    def shape_referential
      workgroup.shape_referential
    end

    def shape_provider
      workbench.default_shape_provider
    end

    def import!
      source.shapes.each_slice(1000).each do |gtfs_shapes|
        gtfs_shapes.each do |gtfs_shape|
          Shape.transaction do
            Decorator.new(gtfs_shape, shape_referential: shape_referential, shape_provider: shape_provider).shape.save!
          end
        end
      end
    end

    class Decorator < SimpleDelegator

      def initialize(shape, shape_referential: nil, shape_provider: nil)
        super shape

        @shape_referential = shape_referential
        @shape_provider = shape_provider
      end

      attr_reader :shape_referential, :shape_provider

      def factory
        @factory ||= RGeo::Cartesian.simple_factory(srid: 4326)
      end

      def rgeos_points
        points.map do |point|
          factory.point point.longitude, point.latitude
        end
      end

      def rgeos_geometry
        factory.line_string rgeos_points
      end

      def shape_attributes
        {
          geometry: rgeos_geometry,
          shape_provider: shape_provider
        }
      end

      def shape
        shape_referential.shapes.build shape_attributes
      end

    end

  end


end
