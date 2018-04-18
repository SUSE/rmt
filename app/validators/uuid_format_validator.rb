class UuidFormatValidator < ActiveModel::EachValidator
  UUID_REGEXP = /\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\Z/i

  def validate_each(record, attribute, value)
    record.errors[attribute] << (options[:message] || 'should be formatted as UUID') unless value.nil? || value =~ UUID_REGEXP
  end
end
