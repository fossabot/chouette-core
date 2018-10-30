class Aggregate < ActiveRecord::Base
  include OperationSupport

  belongs_to :workgroup
  has_many :compliance_check_sets, -> { where(parent_type: "Aggregate") }, foreign_key: :parent_id, dependent: :destroy

  validates :workgroup, presence: true

  after_commit :aggregate, on: :create

  delegate :output, to: :workgroup

  def parent
    workgroup
  end

  def aggregate
    update_column :started_at, Time.now
    update_column :status, :running

    AggregateWorker.perform_async(id)
  end

  def aggregate!
    prepare_new

    referentials.each do |source|
      ReferentialCopy.new(source: source, target: new).copy!
    end

    if after_aggregate_compliance_control_set.present?
      create_after_aggregate_compliance_check_set
    else
      save_current
    end
  rescue => e
    Rails.logger.error "Aggregate failed: #{e} #{e.backtrace.join("\n")}"
    failed!
    raise e if Rails.env.test?
  end

  private

  def prepare_new
    Rails.logger.debug "Create a new output"
    # 'empty' one
    attributes = {
      organisation: workgroup.owner,
      prefix: "aggregate_#{id}",
      line_referential: workgroup.line_referential,
      stop_area_referential: workgroup.stop_area_referential,
      objectid_format: referentials.first.objectid_format
    }
    new = workgroup.output.referentials.new attributes
    new.referential_suite = output
    new.slug = "output_#{workgroup.id}_#{created_at.to_i}"
    new.name = I18n.t("aggregates.referential_name", date: I18n.l(created_at))

    unless new.valid?
      Rails.logger.error "New referential isn't valid : #{new.errors.inspect}"
    end

    begin
      new.save!
    rescue
      Rails.logger.debug "Errors on new referential: #{new.errors.messages}"
      raise
    end

    new.pending!

    output.update new: new
    update new: new
  end

  def after_aggregate_compliance_control_set
    @after_aggregate_compliance_control_set ||= workgroup.compliance_control_set(:after_aggregate)
  end

  def create_after_aggregate_compliance_check_set
    create_compliance_check_set :after_aggregate, after_aggregate_compliance_control_set, new
  end
end
