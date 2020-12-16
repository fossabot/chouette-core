module LazyLoading
  class Company
    def initialize(query_ctx, company_id)
      @company_id = company_id
      # Initialize the loading state for this query or get the previously-initiated state
      @lazy_state = query_ctx[:lazy_find_company] ||= {
        pending_ids: Set.new,
        loaded_ids: {},
      }
      # Register this ID to be loaded later:
      @lazy_state[:pending_ids] << company_id
    end

    # Return the loaded record, hitting the database if needed
    def company
      # Check if the record was already loaded:
      loaded_record = @lazy_state[:loaded_ids][@company_id]
      if loaded_record
        # The pending IDs were already loaded so return the result of that previous load
        loaded_record
      else
        # The record hasn't been loaded yet, so hit the database with all pending IDs
        pending_ids = @lazy_state[:pending_ids].to_a
        companies = Chouette::Company.where(id: pending_ids)

        # Fill and clean the map
        companies.each { |company| @lazy_state[:loaded_ids][company.id] = company }
        @lazy_state[:pending_ids].clear

        # Now, get the matching companies from the loaded result:
        @lazy_state[:loaded_ids][@company_id]
      end
    end
  end
end
