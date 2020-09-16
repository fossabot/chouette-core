module LazyLoading
  class ServiceCount
    def initialize(query_ctx, line_id)
      @line_id = line_id
      # Initialize the loading state for this query or get the previously-initiated state
      @lazy_state = query_ctx[:lazy_find_line_service_counts] ||= {
        pending_ids: Set.new,
        loaded_ids: {},
      }
      # Register this ID to be loaded later:
      @lazy_state[:pending_ids] << line_id
    end

    # Return the loaded record, hitting the database if needed
    def service_count
      # Check if the record was already loaded:
      loaded_records = @lazy_state[:loaded_ids][@line_id]
      if loaded_records
        # The pending IDs were already loaded so return the result of that previous load
        loaded_records
      else
        # The record hasn't been loaded yet, so hit the database with all pending IDs
        pending_ids = @lazy_state[:pending_ids].to_a
        service_counts = Stat::JourneyPatternCoursesByDate.for_lines(pending_ids).select('*')

        # Fill and clean the map
        service_counts.each do |service_count|
          # puts service_count.inspect
          @lazy_state[:loaded_ids][service_count.line_id] ||= 0
          @lazy_state[:loaded_ids][service_count.line_id] += service_count.count
        end
        @lazy_state[:pending_ids].clear

        # Now, get the matching lines from the loaded result:
        @lazy_state[:loaded_ids][@line_id]
      end
    end
  end
end
