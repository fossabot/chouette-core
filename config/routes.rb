ChouetteIhm::Application.routes.draw do
  resource :dashboard
  resource :subscriptions, only: :create
  resources :notifications, only: :index

  # FIXME See CHOUETTE-207
  resources :exports, only: :upload do
    post :upload, on: :member, controller: :export_uploads
  end

  # Used to the redirect user to the current workbench
  # See CHOUETTE-797
  namespace :redirect do
    resources :lines, only: :show
    resources :companies, only: :show
    resources :stop_areas, only: :show
  end

  namespace :refresh_form do
    resource :export, only: [] do
      get :edit_type, on: :collection
      get :edit_exported_lines, on: :collection
      get :set_export_type, on: :collection
    end

    resource :publication_setup, only: [] do
      get :edit_type, on: :collection
      get :edit_exported_lines, on: :collection
    end
  end

  concern :iev_interfaces do
    resources :imports do
      get :download, on: :member
      get :internal_download, on: :member
      resources :import_resources, only: [:index, :show] do
        resources :import_messages, only: [:index]
      end
    end

    resources :exports do
      get :refresh_form, on: :collection
      post :upload, on: :member
      get :download, on: :member
    end
  end

  resources :workbenches, except: [:destroy], concerns: :iev_interfaces do
    delete :referentials, on: :member, action: :delete_referentials
    resources :api_keys

    resources :autocomplete, only: %i[lines companies line_providers] do
      get :lines, on: :collection, defaults: { format: 'json' }
      get :companies, on: :collection, defaults: { format: 'json' }
      get :line_providers, on: :collection, defaults: { format: 'json' }
    end

    resources :compliance_check_sets, only: [:index, :show] do
      get :executed, on: :member
      resources :compliance_checks, only: [:show]
      resources :compliance_check_messages, only: [:index]
    end

    resource :output, controller: :workbench_outputs
    resources :merges do
      member do
        put :rollback
      end
      collection do
        get :available_referentials
      end
    end

    resources :referentials, only: %w(new create index)
    resources :notification_rules

    resource :stop_area_referential, :only => [:show, :edit, :update] do
      post :sync, on: :member
      resources :stop_area_providers do
        get :autocomplete, on: :collection
      end
      resources :stop_area_routing_constraints
      resources :stop_areas do
        get :autocomplete, on: :collection
      end
      resources :connection_links
    end

    resource :line_referential, :only => [:show, :edit, :update] do
      post :sync
      resources :lines do
        member do
          get :available_line_notices
        end
        resources :line_notices do
          collection do
            get :attach
          end

          member do
            post :detach
          end
        end
      end
      resources :companies
      resources :networks
      resources :line_notices
    end

    resource :shape_referential do
      resources :shapes, except: [:create] do
        get :associations, on: :member
      end
    end
  end

  resources :workgroups, except: [:destroy], concerns: :iev_interfaces do
    put :setup_deletion, on: :member
    put :remove_deletion, on: :member

    member do
      get :edit_aggregate
      get :edit_controls
      put :update_controls
      get :edit_merge
      get :edit_transport_modes
    end

    resources :compliance_check_sets, only: [:index, :show] do
      get :executed, on: :member
      resources :compliance_checks, only: [:show]
      resources :compliance_check_messages, only: [:index]
    end

    resources :workbenches, controller: :workgroup_workbenches, only: [:show, :edit, :update]

    resource :output, controller: :workgroup_outputs
    resources :aggregates do
      member do
        put :rollback
      end
    end

    resources :publication_setups do
      resources :publications, only: :show
    end

    resources :publication_apis do
      resources :publication_api_keys
    end

    resources :calendars do
      get :autocomplete, on: :collection, controller: 'autocomplete_calendars'
      member do
        get 'month', defaults: { format: :json }
      end
    end

    resources :autocomplete, only: %i[lines companies line_providers] do
      get :lines, on: :collection, defaults: { format: 'json' }
      get :companies, on: :collection, defaults: { format: 'json' }
      get :line_providers, on: :collection, defaults: { format: 'json' }
    end
  end

  resources :referentials, except: %w(new create index) do

    member do
      put :archive
      put :unarchive
      get :select_compliance_control_set
      post :validate
      put :clean
    end

    resources :autocomplete_stop_areas, only: [:show, :index] do
      get 'around', on: :member
    end
    resources :autocomplete_purchase_windows, only: [:index]
    resources :autocomplete_time_tables, only: [:index]

    resources :autocomplete, only: %i[lines companies line_providers] do
      get :lines, on: :collection, defaults: { format: 'json' }
      get :companies, on: :collection, defaults: { format: 'json' }
      get :line_providers, on: :collection, defaults: { format: 'json' }
    end


    match 'lines' => 'lines#destroy_all', :via => :delete
    resources :lines, controller: "referential_lines", except: :index do
      get :autocomplete, on: :collection, to: 'autocomplete_lines#index'

      resources :footnotes do
        collection do
          get 'edit_all'
          patch 'update_all'
        end
      end
      delete :index, on: :collection, action: :delete_all
      collection do
        get 'name_filter'
      end
      resources :routes do
        member do
          get 'edit_boarding_alighting'
          put 'save_boarding_alighting'
          get 'costs'
          post 'duplicate', to: 'routes#duplicate'
        end
        collection do
          get 'fetch_opposite_routes'
          get 'fetch_user_permissions'
        end
        resource :journey_patterns_collection, :only => [:show, :update]
        resources :journey_patterns do
          get 'new_vehicle_journey', on: :member
          get 'available_specific_stop_places', on: :member
        end
        resource :vehicle_journeys_collection, :only => [:show, :update]
        resources :vehicle_journeys, :vehicle_journey_frequencies do
          get 'select_journey_pattern', :on => :member
          get 'select_vehicle_journey', :on => :member
          resources :vehicle_translations
          resources :time_tables
        end
        resources :vehicle_journey_imports
        resources :vehicle_journey_exports
        resources :stop_points, only: :index, controller: 'route_stop_points'
      end
      resources :routing_constraint_zones
    end

    resources :vehicle_journeys, controller: 'referential_vehicle_journeys', only: [:index]

    resources :purchase_windows

    resources :time_tables do
      collection do
        get :tags
      end
      member do
        post 'actualize'
        get 'duplicate'
        get 'month', defaults: { format: :json }
      end
      resources :time_table_dates
      resources :time_table_periods
      resources :time_table_combinations
    end
    resources :clean_ups
  end

  devise_for :users, :controllers => {
    confirmations: 'users/confirmations',
    invitations: 'users/invitations',
    passwords: 'users/passwords'
  }

  devise_scope :user do
    authenticated :user do
      root :to => 'workbenches#index', as: :authenticated_root
    end

    unauthenticated :user do
      target = 'devise/sessions#new'

      if Rails.application.config.chouette_authentication_settings[:type] == "cas"
        target = 'devise/cas_sessions#new'
      end

      root :to => target, as: :unauthenticated_root
    end
  end

  # TODO: rename this var
  if SmartEnv.boolean "BYPASS_AUTH_FOR_SIDEKIQ"
    match "/delayed_job" => DelayedJobWeb, :anchor => false, :via => [:get, :post]
  else
    authenticate :user, lambda { |u| u.can_monitor_sidekiq? } do
      match "/delayed_job" => DelayedJobWeb, :anchor => false, :via => [:get, :post]
    end
  end

  namespace :api do
    namespace :v1 do
      get 'datas/:slug', to: 'datas#infos', as: :infos

      # Don't move after get 'datas/:slug/*key' CHOUETTE-1105
      get 'datas/:slug/lines', to: 'datas#lines', as: :lines
      post 'datas/:slug/graphql', to: "datas#graphql", as: :graphql

      get 'datas/:slug/*key', to: 'datas#download', :format => false
      get 'datas/:slug.*key', to: 'datas#redirect', :format => false

      resources :workbenches, only: [] do
        resources :imports, only: [:index, :show, :create]
      end

      post 'stop_area_referentials/:id/webhook', to: 'stop_area_referentials#webhook'
      post 'line_referentials/:id/webhook', to: 'line_referentials#webhook'

      namespace :internals do
        get 'compliance_check_sets/:id/notify_parent', to: 'compliance_check_sets#notify_parent'

        get 'netex_exports/:id/notify_parent', to: 'netex_exports#notify_parent'
        post 'netex_exports/:id/upload', to: 'netex_exports#upload'

        resources :netex_imports, only: :create do
          member do
            get :notify_parent
            get :download
          end
        end
      end
    end
  end

  resource :organisation, :only => [:show, :edit, :update] do
    resources :users do
      member do
        put :block
        put :unblock
        put :reinvite
        put :reset_password
      end

      collection do
        get :new_invitation
        post :invite
      end
    end
  end

  resources :compliance_control_sets do
    get :simple, on: :member
    get :clone, on: :member
    resources :compliance_controls, except: :index do
      get :select_type, on: :collection
    end
    resources :compliance_control_blocks, :except => [:show, :index]
  end

  resources :companies do
    get :autocomplete, on: :collection, controller: 'autocomplete_companies'
  end

  resources :calendars do
    get :autocomplete, on: :collection, controller: 'autocomplete_calendars'
    member do
      get 'month', defaults: { format: :json }
    end
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if %i[letter_opener_web letter_opener].include?(Rails.application.config.action_mailer.delivery_method)

  root :to => "dashboards#show"

  if Rails.env.development? || Rails.env.test?
    get "/snap" => "snapshots#show"
  end

  if Rails.application.config.development_toolbar
    post "/development_toolbar" => "development_toolbar#update_settings", as: :development_toolbar_update_settings
  end

  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
  end

  match '/404', to: 'errors#not_found', via: :all, as: 'not_found'
  match '/403', to: 'errors#forbidden', via: :all, as: 'forbidden'
  match '/422', to: 'errors#server_error', via: :all, as: 'unprocessable_entity'
  match '/500', to: 'errors#server_error', via: :all, as: 'server_error'

  match '/status', to: 'statuses#index', via: :get

end
