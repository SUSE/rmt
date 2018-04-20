# HYPERVISOR_VENDORS => https://github.com/karelzak/util-linux/blob/master/sys-utils/lscpu.c
class HwInfo < ApplicationRecord
  belongs_to :system, inverse_of: :hw_info, dependent: :destroy

  before_validation :make_invalid_uuid_nil

  # We store UUID as a downcased string. Please take that in account in finders
  validates :uuid, uuid_format: true
  validates :system, uniqueness: true, presence: true

  before_save -> { uuid.try(:downcase!) }

  def make_invalid_uuid_nil
    self.uuid = nil unless uuid =~ UuidFormatValidator::UUID_REGEXP
  end
end
