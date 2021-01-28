class CodeSpace < ActiveRecord::Base

  belongs_to :workgroup
  validates :short_name, presence: true

  DEFAULT_SHORT_NAME = 'external'
  PUBLIC_SHORT_NAME  = 'public'

  has_many :codes, dependent: :delete_all

  # WARNING: required a Referential#switch
  has_many :referential_codes

end
