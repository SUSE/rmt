require 'spec_helper'

class UuidFormatValidatable
  include ActiveModel::Validations
  attr_accessor :uuid

  validates :uuid, uuid_format: true
end

describe UuidFormatValidator, type: :model do
  subject { UuidFormatValidatable.new }

  it_behaves_like 'model with UUID format validation on field', :uuid
end
