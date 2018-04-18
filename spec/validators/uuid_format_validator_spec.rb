require 'spec_helper'

class UuidFormatValidatable
  include ActiveModel::Validations
  attr_accessor :uuid

  validates :uuid, uuid_format: true
end

describe UuidFormatValidator, type: :model do
  subject { UuidFormatValidatable.new }

  let(:valid_uuid) { 'aaaaaaaa-aaaa-4aaa-9aaa-aaaaaaaaaaaa' }
  let(:uuid_format_message) { 'should be formatted as UUID' }

  it { is_expected.to allow_value('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa').for(:uuid) }
  it { is_expected.to allow_value('00000000-0000-0000-0000-000000000000').for(:uuid) }
  it { is_expected.to allow_value('F48AF167-f47C-4C67-974E-B502E48C3731').for(:uuid) }

  it { is_expected.not_to allow_value('').for(:uuid).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('a').for(:uuid).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('f48af167d47c4c67974eb502e48c3731').for(:uuid).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('0F48AF167-f47C-4C67-974E-B502E48C37310').for(:uuid).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('F48AF167-f47C-4C67-974E-B502X48C3731').for(:uuid).with_message(uuid_format_message) }
  it { is_expected.not_to allow_value('F48AF167-f47C-4C67-974E-B502E48C373').for(:uuid).with_message(uuid_format_message) }
end
