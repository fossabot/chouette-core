require File.expand_path('../boot', __FILE__)

ENV['RANSACK_FORM_BUILDER'] = '::SimpleForm::FormBuilder'

require 'rails/all'
require_relative '../app/lib/smart_env'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

if defined?(NullDB) and ENV['RAILS_DB_ADAPTER'] != 'nulldb'
  raise "activerecord-nulldb-adapter should not be loaded"
end

module ChouetteIhm
  class Application < Rails::Application

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths << config.root.join('app', 'jobs')
    config.autoload_paths << config.root.join('app', 'lib', 'validators')
    config.autoload_paths << config.root.join('app', 'inserters')

    # custom exception pages
    config.exceptions_app = self.routes

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Paris'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    SmartEnv.add :IEV_URL
    SmartEnv.add :RAILS_ENV
    SmartEnv.add :RAILS_DB_ADAPTER, default: :postgis
    SmartEnv.add :RAILS_DB_HOST, default: 'db'
    SmartEnv.add :RAILS_DB_NAME, default: 'chouette'
    SmartEnv.add :RAILS_DB_PASSWORD
    SmartEnv.add :RAILS_DB_POOLSIZE, default: '40'
    SmartEnv.add :RAILS_DB_PORT, default: '5432'
    SmartEnv.add :RAILS_DB_USER, default: 'chouette'
    # Public URL for this Chouette instance
    SmartEnv.add :PUBLIC_HOST, required: true
    # Private/internal URL for this Chouette instance (for other containers)
    SmartEnv.add :RAILS_HOST
    SmartEnv.add :RAILS_LOCALE, default: :fr
    SmartEnv.add :TEST_ENV_NUMBER
    SmartEnv.add :WORKBENCH_IMPORT_DIR
    SmartEnv.add :CHOUETTE_ADDITIONAL_COMPLIANCE_CONTROLS, default: ""
    SmartEnv.add :CHOUETTE_ADDITIONAL_PUBLICATION_DESTINATIONS, default: ""
    SmartEnv.add :MAIL_FROM, default: 'Chouette <noreply@enroute.mobi>'
    SmartEnv.add_boolean :AUTOMATED_AUDITS_ENABLED
    SmartEnv.add_boolean :BYPASS_AUTH_FOR_SIDEKIQ
    SmartEnv.add_boolean :CHOUETTE_ROUTE_POSITION_CHECK
    SmartEnv.add_boolean :CHOUETTE_ITS_SEND_INVITATION
    SmartEnv.add_boolean :NO_TRANSACTION
    SmartEnv.add_boolean :CHOUETTE_EMAIL_USER
    SmartEnv.add_array :CHOUETTE_EMAIL_WHITELIST
    SmartEnv.add_array :CHOUETTE_EMAIL_BLACKLIST
    SmartEnv.add_boolean :CHOUETTE_TRANSACTIONAL_CHECKSUMS, default: true
    SmartEnv.add_boolean :ENABLE_DELAYED_JOB_REAPER, default: true
    SmartEnv.add_boolean :ENABLE_DEVELOPMENT_TOOLBAR, default: false
    SmartEnv.add_integer :DELAYED_JOB_MAX_RUN_TIME, default: 24
    SmartEnv.add :DELAYED_JOB_REAPER_HEARTBEAT_INTERVAL_SECONDS, default: 20
    SmartEnv.add :DELAYED_JOB_REAPER_HEARTBEAT_TIMEOUT_SECONDS, default: 60
    SmartEnv.add_boolean :DELAYED_JOB_REAPER_WORKER_TERMINATION_ENABLED, default: true
    SmartEnv.add :DEFAULT_CONNECTION_SPEED, default: 4.8
    SmartEnv.add :FREQUENT_TRAVELLER_CONNECTION_SPEED, default: 6
    SmartEnv.add :OCCASIONAL_TRAVELLER_CONNECTION_SPEED, default: 3.5
    SmartEnv.add_integer :REFERENTIALS_CLEANING_COOLDOWN
    SmartEnv.add_boolean :ENABLE_LINK_TO_SUPPORT, default: false
    SmartEnv.add :SUPPORT_LINK, default: 'https://support.enroute.mobi'
    SmartEnv.add_integer :CHOUETTE_IMPORT_MAX_RUNTIME

    # Manage Storage configuration
    SmartEnv.add :STORAGE, default: 'file'
    SmartEnv.add :GCLOUD_PROJECT
    SmartEnv.add :GCLOUD_BUCKET
    SmartEnv.add_boolean :GCLOUD_BUCKET_IS_PUBLIC, default: false
    SmartEnv.add :GCLOUD_AUTHENTICATED_URL_EXPIRATION, default: 600
    SmartEnv.add :GCLOUD_KEYFILE, default: 'config/storage-key.json'

    SmartEnv.add_boolean :FORCE_MERGE_METHOD

    config.i18n.default_locale = SmartEnv[:RAILS_LOCALE].to_sym

    # Configure Browserify to use babelify to compile ES6
    # config.browserify_rails.commandline_options = "-t [ babelify --presets [ react es2015 ] ]"

    config.active_record.observers = [:route_observer, :calendar_observer, :import_observer, :export_observer, :compliance_check_set_observer, :merge_observer, :aggregate_observer]

    config.active_job.queue_adapter = :delayed_job

    config.action_dispatch.rescue_responses.merge!(
      'FeatureChecker::NotAuthorizedError' => :unauthorized
    )

    config.development_toolbar = SmartEnv.boolean('ENABLE_DEVELOPMENT_TOOLBAR')
    if SmartEnv.boolean('ENABLE_DEVELOPMENT_TOOLBAR')
      config.development_toolbar = OpenStruct.new
      config.development_toolbar.features_doc_url = nil
      config.development_toolbar.available_features = %w()
      config.development_toolbar.available_permissions = %w()
      config.development_toolbar.tap do |toolbar|
        eval File.read(Rails.root + 'config/development_toolbar.rb')
      end
    end

    config.enable_calendar_observer = true
    config.subscriptions_notifications_recipients = []
    config.enable_automated_audits = SmartEnv.boolean('AUTOMATED_AUDITS_ENABLED')
    config.automated_audits_recipients = []

    config.vehicle_journeys_extra_headers = []
    config.osm_backgrounds_source = :osm
    config.osm_backgrounds_esri_token = "your_token_here"

    config.additional_compliance_controls = []
    config.additional_compliance_controls.push *SmartEnv["CHOUETTE_ADDITIONAL_COMPLIANCE_CONTROLS"].split(',')

    config.additional_destinations = []
    config.additional_destinations.push *SmartEnv["CHOUETTE_ADDITIONAL_PUBLICATION_DESTINATIONS"].split(',')

    config.enable_transactional_checksums = SmartEnv.boolean('CHOUETTE_TRANSACTIONAL_CHECKSUMS')

    config.connection_speeds = [
        SmartEnv[:DEFAULT_CONNECTION_SPEED],
        SmartEnv[:FREQUENT_TRAVELLER_CONNECTION_SPEED],
        SmartEnv[:OCCASIONAL_TRAVELLER_CONNECTION_SPEED]
    ]

    unless Rails.env.production?
        # Work around sprockets+teaspoon mismatch:
        Rails.application.config.assets.precompile += %w(spec_helper.js)
        # Make sure Browserify is triggered when
        # asked to serve javascript spec files
        # config.browserify_rails.paths << lambda { |p|
        #     p.start_with?(Rails.root.join("spec/javascripts").to_s)
        # }
    end
  end
end
