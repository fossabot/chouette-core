class ApplicationController < ActionController::Base
  include MetadataControllerSupport
  include Pundit
  include FeatureChecker

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # TODO : Delete hack to authorize Cross Request for js and json get request from javascript
  protect_from_forgery unless: -> { request.get? && (request.format.json? || request.format.js?) }
  before_action :authenticate_user!
  before_action :set_locale

  # Load helpers in rails engine
  helper LanguageEngine::Engine.helpers
  layout :layout_by_resource

  def set_locale
    wanted_locale = (params['lang'] || session[:language] || I18n.default_locale).to_sym
    effective_locale = I18n.available_locales.include?(wanted_locale) ? wanted_locale : I18n.default_locale

    I18n.locale = effective_locale
    logger.info "Locale set to #{I18n.locale.inspect}"
  end

  def pundit_user
    UserContext.new(current_user, referential: @referential, workbench: current_workbench)
  end

  protected

  include ErrorManagement
  alias user_not_authorized forbidden

  def current_organisation
    current_user.organisation if current_user
  end

  def current_workbench
    (self.respond_to? :workbench)? workbench : @workbench
  end

  helper_method :current_organisation

  def collection_name
    self.class.name.split("::").last.gsub('Controller', '').underscore
  end

  def decorated_collection
    if instance_variable_defined?("@#{collection_name}")
      instance_variable_get("@#{collection_name}")
    else
      nil
    end
  end
  helper_method :decorated_collection

  def begin_of_association_chain
    current_organisation
  end

  # Overwriting the sign_out redirect path method
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  def store_file_and_clean_cache(source)
    source.file.cache_stored_file!
    CarrierWave.clean_cached_files!
  end

  private

  def layout_by_resource
    if devise_controller?
      "devise"
    else
      "application"
    end
  end

end
