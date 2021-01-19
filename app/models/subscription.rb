# coding: utf-8
class Subscription
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  def self.enabled?
    Rails.application.config.accept_user_creation
  end

  attr_accessor :organisation_name, :user_name, :email, :password, :password_confirmation
  
  validates_presence_of :organisation_name, :user_name, :email, :password, :password_confirmation

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def persisted?
    false
  end

  def user
    @user ||= organisation.users.build name: user_name, email: email, password: password, password_confirmation: password_confirmation, profile: :admin
  end

  def organisation
    @organisation ||= Organisation.new name: organisation_name, code: organisation_name.parameterize, features: Feature.all
  end

  def valid?
    super && organisation.valid? && user.valid?
  end

  def workgroup
    @workgroup ||= Workgroup.create_with_organisation(organisation)
  end

  alias_method :create_workgroup!, :workgroup

  def save
    if valid?
      ActiveRecord::Base.transaction do
        organisation.save!
        user.save!

        create_workgroup!
      end
    end
    valid?
  end

end
