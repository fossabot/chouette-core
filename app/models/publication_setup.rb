module PublicationSetupWithDefaultExportOptions
  def export_options
    super || {}
  end
end

class PublicationSetup < ApplicationModel
  prepend PublicationSetupWithDefaultExportOptions

  belongs_to :workgroup
  has_many :publications, dependent: :destroy
  has_many :destinations, dependent: :destroy, inverse_of: :publication_setup

  validates :name, presence: true
  validates :workgroup, presence: true
  validates :export_type, presence: true
  validate :export_options_are_valid

  store_accessor :export_options

  accepts_nested_attributes_for :destinations, allow_destroy: true, reject_if: :all_blank

  scope :enabled, -> { where enabled: true }

  def export_class
    export_type.presence&.safe_constantize || Export::Base
  end

  def human_export_name
    new_export.human_name
  end

  def export_creator_name
    "#{self.class.ts} #{name}"
  end

  # TODO : CHOUETTE-701 find another way to do use export validation
  def export_options_are_valid
    return false if export_class == Export::Base

    dummy = new_export
    dummy.validate
    errors_keys = new_export.class.options.keys
    dummy.errors.to_h.slice(*errors_keys).each do |k, v|
      errors.add(k, v)
    end
  end

  def published_line_ids(referential)
    line_ids = parse_option :line_ids
    company_ids = parse_option :company_ids
    line_provider_ids = parse_option :line_provider_ids

    options = Export::Scope::Options.new(referential, date_range: date_range, line_ids: line_ids, line_provider_ids: line_provider_ids, company_ids: company_ids)
    
    options.scope.lines.pluck(:id)
  end

  def new_export(extra_options={})
    options = export_options.dup.update(extra_options).symbolize_keys
    export = export_class.new(**options) do |export|
      export.creator = export_creator_name
    end

    yield export if block_given?

    export
  end

  def new_exports(referential)
    common_attributes = {
      referential: referential,
      name: "#{self.class.ts} #{name}",
      synchronous: true,
      workgroup: referential.workgroup
    }

    if publish_per_line
      published_line_ids(referential).map do |line_id|
        new_export(line_ids: [line_id], **common_attributes)
      end
    else
      [new_export(common_attributes)]
    end
  end

  def publish(operation)
    publications.create!(parent: operation)
  end

  private

  def date_range
    duration = parse_option :duration
    return nil if duration.nil?
    Time.now.to_date..duration.to_i.days.from_now.to_date
  end

  def parse_option name
    JSON.parse(export_options[name.to_s])
  rescue
    nil
  end
end
